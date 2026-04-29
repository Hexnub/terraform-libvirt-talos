locals {
  # Controller map — keyed by name so for_each is stable across scale events.
  # IP: .10, .11, .12 … (controller_ip_start + index)
  # MAC: last octet mirrors the IP last octet, keeping MAC↔IP deterministic.
  controllers = {
    for i in range(var.controller_count) :
    "${var.cluster_name}-ctrl-${i + 1}" => {
      role  = "controlplane"
      index = i
      ip    = cidrhost(var.network_cidr, var.controller_ip_start + i)
      mac   = format("52:54:00:12:34:%02x", var.controller_ip_start + i)
    }
  }

  # Worker map — .100, .101, .102 … (worker_ip_start + index)
  workers = {
    for i in range(var.worker_count) :
    "${var.cluster_name}-worker-${i + 1}" => {
      role  = "worker"
      index = i
      ip    = cidrhost(var.network_cidr, var.worker_ip_start + i)
      mac   = format("52:54:00:12:34:%02x", var.worker_ip_start + i)
    }
  }

  all_nodes = merge(local.controllers, local.workers)

  dhcp_range_start = cidrhost(var.network_cidr, var.dhcp_range_start_octet)
  dhcp_range_end   = cidrhost(var.network_cidr, var.dhcp_range_end_octet)
}

# ── Base image ────────────────────────────────────────────────────────────────
# Imported once; all node disks use this as a read-only backing store (qcow2 COW).
resource "libvirt_volume" "talos_base" {
  name = "${var.cluster_name}-talos-base.raw"
  pool = var.libvirt_storage_pool

  target = {
    format = {
      type = "raw"
    }
  }

  create = {
    content = {
      url = "file://${var.base_image_path}"
    }
  }
}

# ── Network ───────────────────────────────────────────────────────────────────
module "network" {
  source = "./modules/network"

  cluster_name     = var.cluster_name
  network_cidr     = var.network_cidr
  dhcp_range_start = local.dhcp_range_start
  dhcp_range_end   = local.dhcp_range_end
}

# ── Nodes ─────────────────────────────────────────────────────────────────────
# One module instance per node. Scaling controller_count or worker_count adds
# or removes only the affected nodes; everything else is untouched.
module "node" {
  for_each = local.all_nodes
  source   = "./modules/node"

  name            = each.key
  role            = each.value.role
  ip              = each.value.ip
  mac             = each.value.mac
  network_name    = module.network.network_name
  base_volume_path = libvirt_volume.talos_base.path
  pool            = var.libvirt_storage_pool

  vcpus     = each.value.role == "controlplane" ? var.controller_vcpus     : var.worker_vcpus
  memory_mb = each.value.role == "controlplane" ? var.controller_memory_mb : var.worker_memory_mb
  disk_gb   = each.value.role == "controlplane" ? var.controller_disk_gb   : var.worker_disk_gb

  ovmf_code_path = var.ovmf_code_path
  ovmf_vars_path = var.ovmf_vars_path
  nvram_dir      = var.nvram_dir
}

# ── DHCP confirmation ─────────────────────────────────────────────────────────
# Polls virsh net-dhcp-leases until each node's MAC appears, confirming the VM
# is online and received its static reservation. Runs after all domains start.
resource "null_resource" "dhcp_wait" {
  for_each = local.all_nodes

  depends_on = [module.node]

  triggers = {
    mac          = each.value.mac
    name         = each.key
    network_name = module.network.network_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "==> Waiting for ${each.key} (MAC ${each.value.mac})..."
      timeout_secs=${var.dhcp_wait_timeout}
      elapsed=0
      network="${module.network.network_name}"
      mac="${each.value.mac}"
      while true; do
        lease=$(virsh net-dhcp-leases "$network" 2>/dev/null | grep -i "$mac" | head -1)
        if [ -n "$lease" ]; then
          confirmed_ip=$(echo "$lease" | awk '{print $5}' | cut -d'/' -f1)
          echo "==> ${each.key} is online at $confirmed_ip"
          break
        fi
        if [ "$elapsed" -ge "$timeout_secs" ]; then
          echo "ERROR: ${each.key} did not obtain a DHCP lease within ${var.dhcp_wait_timeout}s" >&2
          exit 1
        fi
        sleep 10
        elapsed=$((elapsed + 10))
      done
    EOT
  }
}
