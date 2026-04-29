variable "cluster_name" {
  description = "Cluster name — used as the libvirt network name and DNS domain prefix"
  type        = string
}

variable "network_cidr" {
  description = "CIDR block for the NAT network (e.g. 192.168.69.0/24)"
  type        = string
}

variable "dhcp_range_start" {
  description = "First IP in the dynamic DHCP pool (pre-resolved full IP, e.g. 192.168.69.200)"
  type        = string
}

variable "dhcp_range_end" {
  description = "Last IP in the dynamic DHCP pool (pre-resolved full IP, e.g. 192.168.69.254)"
  type        = string
}
