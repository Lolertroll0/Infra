resource "docker_network" "orchestratorInternal" {
  provider   = docker.orchestrator
  name       = "orchestratorInternal"
  internal   = false
  depends_on = [null_resource.setup_OrchestratorEnvironment]
}

resource "null_resource" "setup_OrchestratorEnvironment" {
  triggers = {
    host_ip         = var.orchestrator
    adminUser       = var.adminUser
    orchestratorKey = var.orchestratorKey
    caddyfile_hash  = md5(file("${path.module}/caddyfile"))
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
      "sudo tailscale up --authkey=${var.tailscaleOrchestratorAuthKey} --ssh",
      "sudo tailscale serve reset",
      "sudo tailscale serve --bg --service=svc:vaultwarden --https=443 http://127.0.0.1:80",
      "sudo tailscale serve --bg --service=svc:uptime-kuma --https=443 http://127.0.0.1:80",
      "sudo tailscale serve --bg --service=svc:homeassistant --https=443 http://127.0.0.1:80",
      "sudo tailscale serve --bg --service=svc:ezbk --https=443 http://127.0.0.1:80",
      "mkdir -p ${local.config_dir}/caddyProxy",
      "touch ${local.config_dir}/caddyProxy/Caddyfile",
      "mkdir -p ${local.data_dir}/caddyProxy",
      "mkdir -p ${local.data_dir}/uptimeKuma",
      "mkdir -p ${local.data_dir}/vaultwarden",
      "mkdir -p ${local.data_dir}/duplicati"
    ]
    connection {
      type        = "ssh"
      host        = var.orchestrator
      user        = var.adminUser
      private_key = file(var.orchestratorKey)
      timeout     = "10m"
    }
  }
  provisioner "remote-exec" { # Provisioner for destroying 
    when = destroy
    inline = [
      "set +e",
      "DEVICE_ID=$(sudo tailscale status --json 2>/dev/null | jq -r '.Self.ID')",
      "if [ -n \"$$DEVICE_ID\" ]; then curl -s -u \"${self.triggers.tailscaleSecret}:\" -X DELETE https://api.tailscale.com/api/v2/device/$$DEVICE_ID; fi",
      "sudo tailscale logout",
      "exit 0"
    ]
    connection {
      type        = "ssh"
      host        = self.triggers.host_ip
      user        = self.triggers.adminUser
      private_key = file(self.triggers.orchestratorKey)
      timeout     = "5m"
    }
  }
  provisioner "file" {
    content     = templatefile("${path.module}/caddyfile", { tailnet = var.tailnet })
    destination = "${local.config_dir}/caddyProxy/Caddyfile"

    connection {
      type        = "ssh"
      host        = var.orchestrator
      user        = var.adminUser
      private_key = file(var.orchestratorKey)
      timeout     = "5m"
    }
  }
}
resource "docker_container" "uptimeKuma" {
  provider = docker.orchestrator
  name     = "uptimeKuma"
  image    = docker_image.uptimeKuma.name
  restart  = "unless-stopped"
  networks_advanced {
    name = docker_network.orchestratorInternal.name
  }

  volumes {
    container_path = "/data"
    host_path      = "${local.data_dir}/uptimeKuma"
  }
  depends_on = [
    docker_container.caddyProxy,
    null_resource.setup_OrchestratorEnvironment
  ]
}
resource "docker_container" "caddyProxy" {
  provider = docker.orchestrator
  name     = "caddyProxy"
  image    = docker_image.caddyProxy.name
  restart  = "unless-stopped"
  dns      = ["100.100.100.100"]

  env = [
    "CADDYFILE_HASH=${md5(file("${path.module}/caddyfile"))}"
  ]

  networks_advanced {
    name = docker_network.orchestratorInternal.name
  }
  capabilities {
    add = ["CAP_NET_ADMIN", "CAP_NET_BIND_SERVICE"]
  }
  ports {
    internal = 80
    external = 80
  }

  volumes {
    container_path = "/etc/caddy/Caddyfile"
    host_path      = "${local.config_dir}/caddyProxy/Caddyfile"
  }
  volumes {
    container_path = "/data"
    host_path      = "${local.data_dir}/caddyProxy"
  }
  depends_on = [null_resource.setup_OrchestratorEnvironment]
}

resource "docker_container" "vaultWarden" {
  provider = docker.orchestrator
  name     = "vaultwarden"
  image    = docker_image.vaultWarden.name
  restart  = "unless-stopped"

  networks_advanced {
    name = docker_network.orchestratorInternal.name
  }

  volumes {
    container_path = "/data"
    host_path      = "${local.data_dir}/vaultwarden"
  }
  depends_on = [
    docker_container.caddyProxy,
    null_resource.setup_OrchestratorEnvironment
  ]
  env = [
    "SIGNUPS_ALLOWED=yes",
    "EMERGENCY_ACCESS_ALLOWED=true",
    "PASSWORD_HINTS_ALLOWED=false"
  ]
}

resource "docker_container" "duplicati" {
  provider = docker.orchestrator
  name     = "duplicati"
  image    = docker_image.duplicati.name
  restart  = "unless-stopped"

  networks_advanced {
    name = docker_network.orchestratorInternal.name
  }

  ports {
    internal = 8200
    external = 8200
  }

  volumes {
    container_path = "/data"
    host_path      = "${local.data_dir}/duplicati"
  }
  volumes {
    container_path = "/source/uptimeKuma"
    host_path      = "${local.data_dir}/uptimeKuma"
  }
  volumes {
    container_path = "/source/vaultwarden"
    host_path      = "${local.data_dir}/vaultwarden"
  }
  depends_on = [
    docker_container.caddyProxy,
    null_resource.setup_OrchestratorEnvironment
  ]
  env = [
    "DUPLICATI__WEBSERVICE_PASSWORD=${var.adminPassword}"
  ]
}
