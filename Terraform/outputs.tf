output "controller_ips" {
  description = "Controller name → static IP"
  value = {
    for name, node in local.controllers : name => node.ip
  }
}

output "worker_ips" {
  description = "Worker name → static IP"
  value = {
    for name, node in local.workers : name => node.ip
  }
}

output "network_bridge" {
  description = "Linux bridge interface name on the KVM host"
  value       = module.network.bridge_name
}

output "vnc_hint" {
  description = "How to reach a node's graphical console"
  value       = "Run 'virsh domdisplay <node-name>' on the KVM host to get the VNC port, then open virt-manager or run 'virt-viewer <node-name>'."
}
