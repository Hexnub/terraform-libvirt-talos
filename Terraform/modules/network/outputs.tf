output "network_id" {
  description = "Libvirt network resource ID"
  value       = libvirt_network.cluster.id
}

output "network_name" {
  description = "Libvirt network name (used in virsh net-update and virsh net-dhcp-leases)"
  value       = libvirt_network.cluster.name
}

output "bridge_name" {
  description = "Linux bridge interface name"
  value       = local.bridge_name
}
