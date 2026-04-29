# ── Static DHCP reservation ───────────────────────────────────────────────────
resource "null_resource" "dhcp_host" {
  triggers = {
    network = var.network_name
    mac     = var.mac
    ip      = var.ip
    name    = var.name
  }

  provisioner "local-exec" {
    command = <<-EOT
      virsh net-update "${var.network_name}" add ip-dhcp-host \
        "<host mac='${var.mac}' name='${var.name}' ip='${var.ip}'/>" \
        --live --config
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      virsh net-update "${self.triggers.network}" delete ip-dhcp-host \
        "<host mac='${self.triggers.mac}'/>" --live --config || true
    EOT
  }
}

# ── Boot disk ─────────────────────────────────────────────────────────────────
resource "libvirt_volume" "disk" {
  name     = "${var.name}.qcow2"
  pool     = var.pool
  capacity = var.disk_gb * 1073741824

  target = {
    format = {
      type = "qcow2"
    }
  }

  backing_store = {
    path = var.base_volume_path
    format = {
      type = "raw"
    }
  }
}

# ── Domain XML ────────────────────────────────────────────────────────────────
# Written to /tmp so virsh define can read it. The local_file resource manages
# creation and cleanup; libvirt_domain is bypassed entirely to avoid provider
# schema inconsistencies around UEFI features/ACPI support in v0.9.x.
resource "local_file" "domain_xml" {
  content = templatefile("${path.module}/domain.xml.tpl", {
    name           = var.name
    vcpus          = var.vcpus
    memory_mb      = var.memory_mb
    disk_path      = libvirt_volume.disk.path
    network_name   = var.network_name
    mac            = var.mac
    ovmf_code_path = var.ovmf_code_path
    ovmf_vars_path = var.ovmf_vars_path
    nvram_path     = "${var.nvram_dir}/${var.name}_VARS.fd"
  })
  filename        = "/tmp/terraform-${var.name}-domain.xml"
  file_permission = "0644"
}

# ── Virtual machine ───────────────────────────────────────────────────────────
# Uses virsh define + start instead of libvirt_domain so the full domain XML
# is controlled directly — UEFI loader, ACPI, APIC, VNC, serial console.
resource "null_resource" "domain" {
  depends_on = [null_resource.dhcp_host, libvirt_volume.disk, local_file.domain_xml]

  triggers = {
    name       = var.name
    domain_xml = local_file.domain_xml.content
  }

  provisioner "local-exec" {
    command = <<-EOT
      virsh define ${local_file.domain_xml.filename}
      virsh autostart ${var.name}
      virsh start ${var.name}
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      virsh destroy ${self.triggers.name} 2>/dev/null || true
      virsh undefine ${self.triggers.name} --nvram 2>/dev/null || true
    EOT
  }
}
