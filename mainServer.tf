resource "proxmox_vm_qemu" "HomeAssistantOS" {
  name               = "HomeAssistantOS"
  description        = "Main Home Automation Server"
  target_node        = "mainserver"
  start_at_node_boot = true
  startup            = "order=1"
  clone              = var.haosTemplate
  full_clone         = true
  scsihw             = "virtio-scsi-pci"
  agent              = 1
  bios               = "ovmf"
  machine            = "q35"
  cores              = 2
  sockets            = 1
  memory             = 4096

  os_type    = "cloud-init"
  ciuser     = var.adminUser
  cipassword = var.adminPassword

  # trimspace removes trailing newlines that corrupt Cloud-Init YAML injection
  sshkeys = var.homeAssistantKeyPublic != "" ? trimspace(file(var.homeAssistantKeyPublic)) : ""

  ipconfig0 = "ip=${var.homeAssistantIP}/24,gw=${var.networkGateway}"

  disk {
    slot    = "scsi0"
    type    = "disk"
    size    = "64G"
    storage = var.proxmoxStorage
  }

  disk {
    slot    = "ide0"
    type    = "cloudinit"
    storage = var.proxmoxStorage
  }

  efidisk {
    efitype = "4m"
    storage = var.proxmoxStorage
  }

  network {
    id = 0

    bridge = "vmbr0"
    model  = "virtio"
  }

  lifecycle {
    ignore_changes = [
      usbs,
      disk,
      efidisk,
      sshkeys,
      shares,
    ]
  }
}





resource "proxmox_vm_qemu" "ezBookKeeping" {
  name               = "ezBookKeeping"
  description        = "EZ Bookkeeping"
  target_node        = "mainserver"
  start_at_node_boot = true
  startup            = "order=2"
  clone              = var.ezbkTemplate
  full_clone         = false
  scsihw             = "virtio-scsi-pci"
  cores              = 2
  sockets            = 1
  memory             = 4096

  agent = 1

  os_type    = "cloud-init"
  ciuser     = var.adminUser
  cipassword = var.adminPassword

  # trimspace removes trailing newlines that corrupt Cloud-Init YAML injection
  sshkeys = var.otherServicesKeyPublic != "" ? trimspace(file(var.otherServicesKeyPublic)) : ""

  ipconfig0 = "ip=192.168.1.102/24,gw=${var.networkGateway}"

  disk {
    slot    = "scsi0"
    type    = "disk"
    size    = "64G"
    storage = var.proxmoxStorage
  }

  disk {
    slot    = "ide0"
    type    = "cloudinit"
    storage = var.proxmoxStorage
  }

  network {
    id     = 0
    bridge = "vmbr0"
    model  = "virtio"
  }

  lifecycle {
    ignore_changes = [
      disk,
      sshkeys,
      shares,
    ]
  }
}

# --- DOCKER PROVISIONING ---
# Wait for the VM to boot, then install Docker and Tailscale
resource "null_resource" "setup_financial_assistant" {
  depends_on = [proxmox_vm_qemu.ezBookKeeping]

  triggers = {
    host_ip          = proxmox_vm_qemu.ezBookKeeping.default_ipv4_address
    adminUser        = var.adminUser
    otherServicesKey = var.otherServicesKey
    tailscaleSecret  = var.tailscaleSecret
  }

  provisioner "remote-exec" {
    inline = [
      "set -x",
      "sudo systemctl enable --now serial-getty@ttyS0.service",
      "if command -v docker >/dev/null 2>&1; then echo \"Docker is already installed.\"; else curl -fsSL https://get.docker.com | sh; fi",
      "sudo systemctl enable --now docker",
      "sudo usermod -aG docker ${var.adminUser}",
      "if command -v tailscale >/dev/null 2>&1; then echo \"Tailscale is already installed.\"; else curl -fsSL https://tailscale.com/install.sh | sudo sh; fi",
      "if ! sudo tailscale status >/dev/null 2>&1; then sudo tailscale up --authkey=${var.tailscaleMainAuthKey} --ssh --accept-risk=lose-ssh; fi",
      "mkdir -p ${local.data_dir}/firefly/upload ${local.data_dir}/ezbk/conf ${local.data_dir}/ezbk/data ${local.data_dir}/ezbk/storage ${local.data_dir}/ezbk/log",
      "sudo chown -R 1000:1000 ${local.data_dir}/firefly ${local.data_dir}/ezbk"
    ]

    connection {
      type = "ssh"
      # If using DHCP, Proxmox provider returns the IP in default_ipv4_address
      host        = var.otherServicesIP
      user        = var.adminUser
      private_key = var.otherServicesKey != "" ? file(var.otherServicesKey) : null
      timeout     = "10m"
    }
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/scripts/ff3-vars.sh"
    environment = {
      GDRIVE_AUTH_ID = var.gDriveAuthID
      PASSPHRASE     = var.adminPassword
      ORCHESTRATOR   = var.orchestrator
      TARGET_NODE    = var.otherServicesIP
    }
  }

}

resource "docker_network" "financial_assistant_net" {
  provider = docker.otherServices
  name     = "financial_assistant_net"
  internal = false
}

resource "docker_container" "financial_assistant" {
  name       = "financial_assistant"
  image      = docker_image.firefly.name
  provider   = docker.otherServices
  depends_on = [null_resource.setup_financial_assistant]

  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.financial_assistant_net.name
  }

  volumes {
    container_path = "/var/www/html/.env"
    host_path      = "${local.config_dir}/firefly/.env"
    read_only      = true
  }

  volumes {
    container_path = "/var/www/html/storage/upload"
    host_path      = "${local.data_dir}/firefly/upload"
  }

  ports {
    internal = 8080
    external = 8081
  }
}

resource "docker_container" "ezbookkeeping" {
  name       = "ezbookkeeping"
  image      = docker_image.ezbookkeeping.name
  provider   = docker.otherServices
  depends_on = [null_resource.setup_financial_assistant]

  restart = "unless-stopped"

  volumes {
    container_path = "/ezbookkeeping/data"
    host_path      = "${local.data_dir}/ezbk/data"
  }
  volumes {
    container_path = "/ezbookkeeping/storage"
    host_path      = "${local.data_dir}/ezbk/storage"
  }
  volumes {
    container_path = "/ezbookkeeping/log"
    host_path      = "${local.data_dir}/ezbk/log"
  }
  ports {
    internal = 8080
    external = 8080
  }
}

resource "docker_volume" "financial_assistant_db" {
  provider = docker.otherServices
  name     = "financial_assistant_db"
}

resource "docker_container" "financial_assistant_db" {
  name       = "financial_assistant_db"
  image      = docker_image.firefly_db.name
  provider   = docker.otherServices
  depends_on = [null_resource.setup_financial_assistant]
  restart    = "unless-stopped"

  networks_advanced {
    name = docker_network.financial_assistant_net.name
  }

  volumes {
    container_path = "/var/lib/mysql"
    volume_name    = docker_volume.financial_assistant_db.name
  }

  volumes {
    container_path = "/run/secrets/.db.env"
    host_path      = "${local.config_dir}/firefly/.db.env"
    read_only      = true
  }

  upload {
    content    = <<EOF
#!/bin/bash
set -a
source /run/secrets/.db.env
set +a
exec /usr/local/bin/docker-entrypoint.sh mysqld
EOF
    file       = "/custom-entrypoint.sh"
    executable = true
  }

  entrypoint = ["/custom-entrypoint.sh"]
}

resource "null_resource" "attach_haos_usb" {
  count      = var.homeAssistantUSB != "" ? 1 : 0
  depends_on = [proxmox_vm_qemu.HomeAssistantOS]

  triggers = {
    vm_id      = proxmox_vm_qemu.HomeAssistantOS.id
    usb_device = var.homeAssistantUSB
  }

  provisioner "remote-exec" {
    inline = [
      "qm set ${proxmox_vm_qemu.HomeAssistantOS.vmid} -usb0 host=${var.homeAssistantUSB}"
    ]

    connection {
      type        = "ssh"
      host        = var.mainServer
      user        = "root"
      private_key = var.mainKey != "" ? file(var.mainKey) : null
      timeout     = "5m"
    }
  }
}

