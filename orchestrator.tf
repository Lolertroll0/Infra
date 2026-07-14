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
    serve_json_hash = md5(file("${path.module}/serve.json"))
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
      "if ! sudo tailscale status >/dev/null 2>&1; then sudo tailscale up --authkey=${var.tailscaleOrchestratorAuthKey} --ssh --accept-risk=lose-ssh; fi",
      "mkdir -p /home/lolertroll/config/tailscale",
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
      private_key = var.orchestratorKey != "" ? file(var.orchestratorKey) : null
      timeout     = "10m"
    }
  }

  provisioner "file" {
    source      = "${path.module}/serve.json"
    destination = "/home/lolertroll/config/tailscale/serve.json"

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
      "sudo tailscale serve set-config --all /home/lolertroll/config/tailscale/serve.json"
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
    content     = templatefile("${path.module}/caddyfile", { tailnet = var.tailnet })
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
resource "docker_container" "uptimeKuma" {
  provider = docker.orchestrator
  name     = "uptimeKuma"
  image    = docker_image.uptimeKuma.name
  restart  = "unless-stopped"
  dns      = ["100.100.100.100"]
  networks_advanced {
    name = docker_network.orchestratorInternal.name
  }

  volumes {
    container_path = "/app/data"
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
    "SIGNUPS_ALLOWED=false",
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
