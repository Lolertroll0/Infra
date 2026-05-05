resource "docker_network" "orchestratorInternal" {
  provider   = docker.orchestrator
  name       = "orchestratorInternal"
  internal   = true
  depends_on = [null_resource.setup_OrchestratorEnvironment]
}

resource "null_resource" "setup_OrchestratorEnvironment" {
  provisioner "remote-exec" {
    inline = [
      "exec > /tmp/tf-provision.log 2>&1",
      "set -x",
      "export DEBIAN_FRONTEND=noninteractive",
      # Docker is now pre-installed via Vagrant
      "if command -v systemctl >/dev/null 2>&1; then sudo systemctl enable --now docker; elif command -v service >/dev/null 2>&1; then sudo service docker start; fi",
      "curl -fsSL https://tailscale.com/install.sh | sudo sh",
      "sudo tailscale up --authkey=${var.tailscaleEphemeralKey}",

      # Missing volumes setup
      "mkdir -p /home/${var.adminUser}/config/caddyProxy",
      "mkdir -p /home/${var.adminUser}/data/caddyProxy",
      "mkdir -p /home/${var.adminUser}/data/uptimeKuma",
      "mkdir -p /home/${var.adminUser}/data/vaultwarden"
    ]
    connection {
      type        = "ssh"
      host        = var.rp4PrivateIp
      user        = var.adminUser
      private_key = file(var.rp4Key)
      timeout     = "1m"
    }
  }

  provisioner "file" {
    content     = templatefile("${path.module}/caddyfile", { tailnet = var.tailnet })
    destination = "/home/${var.adminUser}/config/caddyProxy/Caddyfile"

    connection {
      type        = "ssh"
      host        = var.rp4PrivateIp
      user        = var.adminUser
      private_key = file(var.rp4Key)
      timeout     = "1m"
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

  ports {
    internal = 3001
    external = 3001
  }

  volumes {
    container_path = "/data"
    host_path      = "/home/${var.adminUser}/data/uptimeKuma"
  }
  depends_on = [
    docker_container.caddyProxy,
    null_resource.setup_OrchestratorEnvironment
  ]
  # TODO: add healthcheck config and logging config

}
resource "docker_container" "caddyProxy" {
  provider = docker.orchestrator
  name     = "caddyProxy"
  image    = docker_image.caddyProxy.name
  restart  = "unless-stopped"

  networks_advanced {
    name = docker_network.orchestratorInternal.name
  }
  capabilities {
    add = ["NET_ADMIN", "NET_BIND_SERVICE"]
  }
  ports {
    internal = 80
    external = 80
  }
  ports {
    internal = 443
    external = 443
  }

  volumes {
    container_path = "/etc/caddy/"
    host_path      = "/home/${var.adminUser}/config/caddyProxy/Caddyfile"
  }
  volumes {
    container_path = "/data"
    host_path      = "/home/${var.adminUser}/data/caddyProxy"
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

  ports {
    internal = 80
    external = 80
  }
  volumes {
    container_path = "/data"
    host_path      = "/home/${var.adminUser}/data/vaultwarden"
  }
  depends_on = [
    docker_container.caddyProxy,
    null_resource.setup_OrchestratorEnvironment
  ]

}
