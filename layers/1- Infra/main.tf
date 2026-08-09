# Environmental Setup for nodes
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
    command = "bash ${path.module}/../../scripts/ff3-vars.sh"
    environment = {
      GDRIVE_AUTH_ID = var.gDriveAuthID
      PASSPHRASE     = var.adminPassword
      ORCHESTRATOR   = var.orchestrator
      TARGET_NODE    = var.otherServicesIP
    }
  }

}

resource "null_resource" "setup_OrchestratorEnvironment" {
  triggers = {
    host_ip           = var.orchestrator
    adminUser         = var.adminUser
    orchestratorKey   = var.orchestratorKey
    caddyfile_hash    = md5(file("${path.module}/../../caddyfile"))
    serve_script_hash = md5(file("${path.module}/../../scripts/setup-tailscale-serve.sh"))
    tailscaleSecret   = var.tailscaleSecret
  }

  provisioner "remote-exec" {
    inline = [
      "exec > /tmp/tf-provision.log 2>&1",
      "set -x",
      "if command -v docker >/dev/null 2>&1; then echo \"Docker is already installed.\"; else curl -fsSL https://get.docker.com | sh; fi",
      "sudo systemctl enable --now docker",
      "sudo usermod -aG docker ${var.adminUser}",
      "if command -v tailscale >/dev/null 2>&1; then echo \"Tailscale is already installed.\"; else curl -fsSL https://tailscale.com/install.sh | sudo sh; fi",
      "if ! sudo tailscale status >/dev/null 2>&1; then sudo tailscale up --authkey=${var.tailscaleOrchestratorAuthKey} --ssh --accept-risk=lose-ssh; fi",
      "mkdir -p ${local.config_dir}/caddyProxy ${local.data_dir}/caddyProxy ${local.data_dir}/uptimeKuma ${local.data_dir}/vaultwarden ${local.data_dir}/duplicati"
    ]
    connection {
      type        = "ssh"
      host        = var.orchestrator
      user        = var.adminUser
      private_key = var.orchestratorKey != "" ? file(var.orchestratorKey) : null
      timeout     = "10m"
    }
  }

  provisioner "file" {
    source      = "${path.module}/../../scripts/setup-tailscale-serve.sh"
    destination = "/tmp/setup-tailscale-serve.sh"

    connection {
      type        = "ssh"
      host        = var.orchestrator
      user        = var.adminUser
      private_key = var.orchestratorKey != "" ? file(var.orchestratorKey) : null
      timeout     = "5m"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sed -i 's/\\r$//' /tmp/setup-tailscale-serve.sh",
      "chmod +x /tmp/setup-tailscale-serve.sh",
      "sudo /tmp/setup-tailscale-serve.sh"
    ]

    connection {
      type        = "ssh"
      host        = var.orchestrator
      user        = var.adminUser
      private_key = var.orchestratorKey != "" ? file(var.orchestratorKey) : null
      timeout     = "5m"
    }
  }

  provisioner "file" {
    content     = templatefile("${path.module}/../../caddyfile", { tailnet = var.tailnet })
    destination = "${local.config_dir}/caddyProxy/Caddyfile"

    connection {
      type        = "ssh"
      host        = var.orchestrator
      user        = var.adminUser
      private_key = var.orchestratorKey != "" ? file(var.orchestratorKey) : null
      timeout     = "5m"
    }
  }
}

resource "null_resource" "setup_voicePipelineEnvironment" {
  triggers = {
    host_ip         = var.voicePipeline
    adminUser       = var.adminUser
    voiceKey        = var.voiceKey
    tailscaleSecret = var.tailscaleSecret
  }

  provisioner "remote-exec" {
    inline = [
      "exec > /tmp/tf-provision.log 2>&1",
      "set -x",
      "if command -v docker >/dev/null 2>&1; then echo \"Docker is already installed.\"; else curl -fsSL https://get.docker.com | sh; fi",
      "sudo systemctl enable --now docker",
      "sudo usermod -aG docker ${var.adminUser}",
      "if command -v tailscale >/dev/null 2>&1; then echo \"Tailscale is already installed.\"; else curl -fsSL https://tailscale.com/install.sh | sudo sh; fi",
      "if ! sudo tailscale status >/dev/null 2>&1; then sudo tailscale up --authkey=${var.tailscaleVoiceAuthKey} --ssh --accept-risk=lose-ssh; fi",
      "mkdir -p ${local.data_dir}/whisper/",
      "mkdir -p ${local.data_dir}/piper/",
      "mkdir -p ${local.data_dir}/ollama/"
    ]
    connection {
      type        = "ssh"
      host        = var.voicePipeline
      user        = var.adminUser
      private_key = var.voiceKey != "" ? file(var.voiceKey) : null
      timeout     = "10m"
    }
  }
}

# Proxmox VM
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
    ignore_changes = all
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
    ]
  }
}

resource "null_resource" "attach_haos_usb" {
  count      = var.homeAssistantUSB != "" ? 1 : 0
  depends_on = [proxmox_vm_qemu.HomeAssistantOS]

  triggers = {
    vm_id      = proxmox_vm_qemu.HomeAssistantOS.id
    usb_device = var.homeAssistantUSB
  }

  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${var.mainServer} 'qm set ${proxmox_vm_qemu.HomeAssistantOS.vmid} -usb0 host=${var.homeAssistantUSB}'"
  }
}

