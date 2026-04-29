variable "name" {
  type        = string
  description = "VM name (e.g. talos-ctrl-1)"
}
variable "role" {
  type        = string
  description = "controlplane or worker"
}
variable "ip" {
  type        = string
  description = "Static IP for DHCP reservation"
}
variable "mac" {
  type        = string
  description = "Fixed MAC address"
}
variable "network_name" {
  type        = string
  description = "Libvirt network name for virsh net-update"
}
variable "base_volume_path" {
  type        = string
  description = "Host filesystem path of the base Talos raw volume (backing store)"
}
variable "pool" {
  type        = string
  description = "Libvirt storage pool name"
}
variable "vcpus" {
  type = number
}
variable "memory_mb" {
  type = number
}
variable "disk_gb" {
  type = number
}
variable "ovmf_code_path" {
  type        = string
  description = "OVMF firmware code path (read-only, shared)"
}
variable "ovmf_vars_path" {
  type        = string
  description = "OVMF vars template path (copied per VM)"
}
variable "nvram_dir" {
  type        = string
  description = "Directory for per-VM NVRAM var files"
}
