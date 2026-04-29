cluster_name    = "talos"
libvirt_uri     = "qemu:///system"
base_image_path = "/var/lib/libvirt/images/talos-metal-amd64.raw"

# UEFI firmware — Arch Linux (edk2-ovmf package)
ovmf_code_path = "/usr/share/edk2/x64/OVMF_CODE.4m.fd"
ovmf_vars_path = "/usr/share/edk2/x64/OVMF_VARS.4m.fd"
nvram_dir      = "/var/lib/libvirt/qemu/nvram"

# Topology
controller_count = 3
worker_count     = 3

# Controller resources
controller_vcpus     = 2
controller_memory_mb = 4096
controller_disk_gb   = 20

# Worker resources
worker_vcpus     = 2
worker_memory_mb = 4096
worker_disk_gb   = 20

# Network — 192.168.69.0/24
# .1         gateway
# .2–.9      admin reserved
# .10–.99    controllers
# .100–.199  workers
# .200–.254  dynamic DHCP
network_cidr           = "192.168.69.0/24"
controller_ip_start    = 10
worker_ip_start        = 100
dhcp_range_start_octet = 200
dhcp_range_end_octet   = 254

dhcp_wait_timeout = 300
