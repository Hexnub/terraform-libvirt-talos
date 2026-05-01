# terraform-libvirt-talos

A fully modular Terraform setup for running a [Talos Linux](https://talos.dev) Kubernetes cluster on KVM/libvirt. I built this for my homelab to have a clean, reproducible way to spin up and tear down a multi-node Talos cluster using nothing but `terraform apply`. No Ansible, no bash spaghetti — just Terraform managing KVM virtual machines with proper UEFI boot, static DHCP, and a dedicated NAT network.

This version gets the nodes up and running with confirmed IPs. Pushing Kubernetes configuration comes in the next stage.

---

## What it does

- Creates a dedicated NAT network (`192.168.69.0/24`) with a clean IP layout
- Boots each node from a shared Talos base image using thin qcow2 overlay disks
- Injects static DHCP reservations so every node always gets the same IP
- Configures UEFI (OVMF) and ACPI — required for Talos to boot
- Sets up VNC on each node so you can pull up a graphical console in virt-manager on demand, without anything auto-launching at deploy time
- Polls DHCP leases until every node is confirmed online, then prints the IPs
- Scales up or down by changing two numbers in `terraform.tfvars`

---

## Prerequisites

- Arch Linux KVM host with `libvirtd` running
- `virsh` in PATH (`sudo pacman -S libvirt`)
- Terraform >= 1.5 (`sudo pacman -S terraform`)
- `edk2-ovmf` for UEFI firmware
- The Talos metal image (instructions below)
- Extras: (`sudo pacman -S qemu iptables-nft dnsmasq virt-manager virtviwer openbsd-netcat dhclient ebtables vde2 bridge-utils`)

---

## 1. Install OVMF

Talos requires EFI boot. SeaBIOS (the QEMU default) will not work.

```bash
sudo pacman -S edk2-ovmf
```

Verify the firmware files are where the Terraform config expects them:

```bash
ls /usr/share/edk2/x64/OVMF_CODE.4m.fd
ls /usr/share/edk2/x64/OVMF_VARS.4m.fd
```

If the paths are different on your system, update `ovmf_code_path` and `ovmf_vars_path` in `Terraform/terraform.tfvars`.

---

## 2. Get the Talos Image

I use a custom image from the Talos Image Factory with the QEMU guest agent extension baked in. This lets virt-manager report IP addresses and makes the nodes more observable inside KVM.

**Build the image:**

1. Go to [factory.talos.dev](https://factory.talos.dev)
2. Select your Talos version (e.g. `v1.9.5`)
3. Under **System Extensions** add: `siderolabs/qemu-guest-agent`
4. Click **Generate** to get a schematic ID
5. Download: Platform `metal`, Architecture `amd64`, Format `.raw.zst`

**Decompress and place it:**

```bash
sudo zstd -d /path/to/metal-amd64.raw.zst \
           -o /var/lib/libvirt/images/talos-metal-amd64.raw

sudo rm /path/to/metal-amd64.raw.zst
```

The default path in `terraform.tfvars` is `/var/lib/libvirt/images/talos-metal-amd64.raw`. Change it if you put it somewhere else.

---

## 3. Firewall

This tripped me up. If you run nftables (which you should be), the default policy drops everything — including DHCP, DNS, and forwarding for your VM bridge. The nodes will boot but sit there with no IP.
Bridge name comes from the cluster name. (br-cluster) configure your nftables.conf accordingly.
You need to allow the KVM bridge (`br-talos`) through your firewall. Add these rules and load them with `sudo nft -f /path/to/nftables.conf`:

```nftables
table inet filter {

    chain vm_input {
        iifname { "virbr1", "br-talos" } udp dport { 53, 67, 123 } accept comment "VM DNS, DHCP, NTP"
        iifname { "virbr1", "br-talos" } tcp dport 53 accept comment "VM DNS TCP"
    }

    chain vm_forward {
        iifname { "virbr1", "br-talos" } accept comment "VM to WAN"
        oifname { "virbr1", "br-talos" } ct state { established, related } accept comment "Return traffic to VMs"
    }

    chain input {
        type filter hook input priority filter; policy drop;
        ct state invalid drop
        ct state { established, related } accept
        iif lo accept
        jump vm_input
    }

    chain forward {
        type filter hook forward priority filter; policy drop;
        jump vm_forward
    }
}

table ip nat {

    chain postrouting {
        type nat hook postrouting priority srcnat; policy accept;
        iifname { "virbr1", "br-talos" } masquerade comment "NAT VM outbound traffic"
    }
}
```

Replace `virbr1` with your default libvirt bridge name if it's different, or remove it if you don't use the default network. A reference copy of this config is at `Terraform/nftables.conf`.

---

## 4. Configure

Open `Terraform/terraform.tfvars` and set your values:

```hcl
cluster_name     = "talos"       # drives all resource names and the bridge name
controller_count = 3
worker_count     = 3
network_cidr     = "192.168.69.0/24"

base_image_path = "/var/lib/libvirt/images/talos-metal-amd64.raw"
ovmf_code_path  = "/usr/share/edk2/x64/OVMF_CODE.4m.fd"
ovmf_vars_path  = "/usr/share/edk2/x64/OVMF_VARS.4m.fd"
```

---

## 5. Deploy

```bash
cd Terraform

terraform init
terraform plan
terraform apply
```

Terraform will create the network, inject DHCP reservations, spin up the VMs, and wait until every node has a confirmed lease. When it finishes you'll see something like:

```
controller_ips = {
  "talos-ctrl-1" = "192.168.69.10"
  "talos-ctrl-2" = "192.168.69.11"
  "talos-ctrl-3" = "192.168.69.12"
}
worker_ips = {
  "talos-worker-1" = "192.168.69.100"
  "talos-worker-2" = "192.168.69.101"
  "talos-worker-3" = "192.168.69.102"
}
```

---

## Scaling

Change the count in `terraform.tfvars` and re-apply. Only the nodes that need to be added or removed are touched — everything else keeps running.

```hcl
worker_count = 5   # adds talos-worker-4 and talos-worker-5
```

```bash
terraform apply
```

To scale down, set it back:

```hcl
worker_count = 3   # destroys talos-worker-4 and talos-worker-5
```

Same works for `controller_count`. The IP scheme has room for up to 90 controllers (`.10`–`.99`) and 100 workers (`.100`–`.199`) before you need to touch anything else.

---

## Console Access

VNC is configured on each node but nothing auto-launches. Connect when you need it:

```bash
# Open virt-manager and double-click the node, or:
virt-viewer talos-ctrl-1

# Get the VNC address/port directly:
virsh domdisplay talos-ctrl-1

# Serial console (good for watching boot output):
virsh console talos-ctrl-1
# Ctrl+] to exit
```

---

## Tearing Down

```bash
terraform destroy
```

Removes all VMs, disks, DHCP reservations, and the network. The base `.raw` image at `/var/lib/libvirt/images/talos-metal-amd64.raw` is left untouched — it's your source file, not a Terraform-managed resource.

---

## IP and MAC Reference

| Range | Purpose |
|---|---|
| `.1` | Gateway |
| `.2` – `.9` | Admin / reserved |
| `.10` – `.99` | Controllers |
| `.100` – `.199` | Workers |
| `.200` – `.254` | Dynamic DHCP (unmanaged VMs) |

MACs follow `52:54:00:12:34:XX` where `XX` is the last IP octet in hex.

| Node | IP | MAC |
|---|---|---|
| talos-ctrl-1 | 192.168.69.10 | 52:54:00:12:34:0a |
| talos-ctrl-2 | 192.168.69.11 | 52:54:00:12:34:0b |
| talos-ctrl-3 | 192.168.69.12 | 52:54:00:12:34:0c |
| talos-worker-1 | 192.168.69.100 | 52:54:00:12:34:64 |
| talos-worker-2 | 192.168.69.101 | 52:54:00:12:34:65 |
| talos-worker-3 | 192.168.69.102 | 52:54:00:12:34:66 |

---

## Troubleshooting

**Nodes boot but get no IP**
Your firewall is blocking DHCP. See the firewall section above. After adding the rules, restart the network and re-inject the DHCP reservations:

```bash
virsh net-destroy talos && virsh net-start talos

terraform apply \
  -replace='module.node["talos-ctrl-1"].null_resource.dhcp_host' \
  -replace='module.node["talos-ctrl-2"].null_resource.dhcp_host' \
  -replace='module.node["talos-ctrl-3"].null_resource.dhcp_host' \
  -replace='module.node["talos-worker-1"].null_resource.dhcp_host' \
  -replace='module.node["talos-worker-2"].null_resource.dhcp_host' \
  -replace='module.node["talos-worker-3"].null_resource.dhcp_host'
```

**VMs shut off immediately after creation**
Missing or wrong OVMF paths. Confirm the firmware files exist at the paths in `terraform.tfvars`:

```bash
ls /usr/share/edk2/x64/OVMF_CODE.4m.fd
ls /usr/share/edk2/x64/OVMF_VARS.4m.fd
```

**"already exists" errors on apply**
Leftover resources from a previous failed run. Clean them up manually then re-apply:

```bash
for vm in talos-ctrl-1 talos-ctrl-2 talos-ctrl-3 \
          talos-worker-1 talos-worker-2 talos-worker-3; do
  virsh destroy $vm 2>/dev/null; virsh undefine $vm --nvram 2>/dev/null
done
virsh vol-delete talos-talos-base.raw --pool default 2>/dev/null
virsh net-destroy talos 2>/dev/null; virsh net-undefine talos 2>/dev/null
rm -f terraform.tfstate terraform.tfstate.backup
terraform apply
```

**Network won't delete via virsh**
If libvirtd is running, `virsh net-destroy` requires an active connection. If it still won't cooperate, stop libvirtd and delete the definition file directly:

```bash
sudo systemctl stop libvirtd
sudo rm -f /var/lib/libvirt/network/talos.xml
sudo rm -f /etc/libvirt/qemu/networks/talos.xml
sudo systemctl start libvirtd
```
