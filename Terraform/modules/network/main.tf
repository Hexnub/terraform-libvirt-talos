locals {
  # Linux kernel enforces a 15-char max on interface names
  bridge_name = substr("br-${var.cluster_name}", 0, 15)
  gateway_ip  = cidrhost(var.network_cidr, 1)
  prefix      = tonumber(split("/", var.network_cidr)[1])
}

resource "libvirt_network" "cluster" {
  name      = var.cluster_name
  autostart = true

  forward = {
    mode = "nat"
  }

  bridge = {
    name  = local.bridge_name
    stp   = "on"
    delay = "0"
  }

  domain = {
    name       = "${var.cluster_name}.local"
    local_only = "yes"
  }

  ips = [
    {
      family  = "ipv4"
      address = local.gateway_ip
      prefix  = local.prefix

      dhcp = {
        # Dynamic pool for non-managed VMs only.
        # Node IPs are pinned via static DHCP entries added per-node by the node module.
        ranges = [
          {
            start = var.dhcp_range_start
            end   = var.dhcp_range_end
          }
        ]
      }
    }
  ]
}
