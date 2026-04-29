# ── Cluster identity ──────────────────────────────────────────────────────────
variable "cluster_name" {
  description = "Cluster name — drives resource names, bridge name (br-<name>), and DNS domain (<name>.local)"
  type        = string
  default     = "talos"
}

variable "libvirt_uri" {
  description = "Libvirt connection URI"
  type        = string
  default     = "qemu:///system"
}

# ── Talos image ───────────────────────────────────────────────────────────────
variable "base_image_path" {
  description = "Absolute path to the decompressed Talos metal .raw image on the KVM host (e.g. /var/lib/libvirt/images/talos-metal-amd64.raw)"
  type        = string
}

# ── UEFI / OVMF ───────────────────────────────────────────────────────────────
variable "ovmf_code_path" {
  description = "OVMF firmware code file — read-only, shared by all VMs (Arch: /usr/share/edk2/x64/OVMF_CODE.fd)"
  type        = string
  default     = "/usr/share/edk2/x64/OVMF_CODE.4m.fd"
}

variable "ovmf_vars_path" {
  description = "OVMF vars template — copied once per VM on first boot (Arch: /usr/share/edk2/x64/OVMF_VARS.fd)"
  type        = string
  default     = "/usr/share/edk2/x64/OVMF_VARS.4m.fd"
}

variable "nvram_dir" {
  description = "Directory where per-VM NVRAM var files are stored — must be writable by the QEMU process"
  type        = string
  default     = "/var/lib/libvirt/qemu/nvram"
}

# ── Topology ──────────────────────────────────────────────────────────────────
variable "controller_count" {
  description = "Number of controller (controlplane) nodes"
  type        = number
  default     = 3
  validation {
    condition     = var.controller_count >= 1
    error_message = "At least one controller is required."
  }
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 3
}

# ── Controller resources ───────────────────────────────────────────────────────
variable "controller_vcpus" {
  type    = number
  default = 2
}
variable "controller_memory_mb" {
  type    = number
  default = 4096
}
variable "controller_disk_gb" {
  type    = number
  default = 20
}

# ── Worker resources ──────────────────────────────────────────────────────────
variable "worker_vcpus" {
  type    = number
  default = 2
}
variable "worker_memory_mb" {
  type    = number
  default = 4096
}
variable "worker_disk_gb" {
  type    = number
  default = 20
}

# ── Networking ────────────────────────────────────────────────────────────────
variable "network_cidr" {
  description = "CIDR for the cluster NAT network"
  type        = string
  default     = "192.168.69.0/24"
}

variable "controller_ip_start" {
  description = "Last-octet start for controller IPs (.10 → .10, .11, .12 ...)"
  type        = number
  default     = 10
}

variable "worker_ip_start" {
  description = "Last-octet start for worker IPs (.100 → .100, .101, .102 ...)"
  type        = number
  default     = 100
}

variable "dhcp_range_start_octet" {
  description = "Last octet of the dynamic DHCP pool start (.200)"
  type        = number
  default     = 200
}

variable "dhcp_range_end_octet" {
  description = "Last octet of the dynamic DHCP pool end (.254)"
  type        = number
  default     = 254
}

variable "libvirt_storage_pool" {
  description = "Libvirt storage pool for all volumes"
  type        = string
  default     = "default"
}

# ── Timeouts ──────────────────────────────────────────────────────────────────
variable "dhcp_wait_timeout" {
  description = "Seconds to wait per node for a confirmed DHCP lease before failing"
  type        = number
  default     = 300
}
