resource "docker_network" "orchestratorInternal" {
  provider = docker.orchestrator
  name = "orchestratorInternal"
  internal = true
}
resource "null_resource" "setup_OrchestratorEnvironment" {
  provisioner "remote-exec" {
    inline = [
      "curl -fsSL https://get.docker.com -o get-docker.sh",
      "sh get-docker.sh",
      "usermod -aG docker vagrant",
      "systemctl enable --now docker",
      "curl -fsSL https://tailscale.com/install.sh | sh",
      "tailscale up --authkey=${var.tailscaleEphemeralKey}"
    ]
    connection {
      type        = "ssh"
      host        = var.rp4PrivateIp
      user        = var.adminUser
      private_key = file("C:/Users/JhonVelasquez/.ssh/orchestrator")
      timeout     = "1m"
    }
  }
}
resource "docker_container" "uptimeKuma" {
  provider = docker.orchestrator
  name = "uptimeKuma"
  image = docker_image.uptimeKuma.name
  restart = "unless-stopped"
  networks_advanced {
    name = docker_network.orchestratorInternal.name
  }

  ports {
    internal = 3001
    external = 3001
  }

  volumes {
    container_path = "/app/data"
    host_path = "/home/${var.adminUser}/data/uptimeKuma" # TODO: Add host path
  }
  depends_on = [ docker_container.caddyProxy ]
  # TODO: add healthcheck config and logging config
  
}
resource "docker_container" "caddyProxy" {
  provider = docker.orchestrator
  name = "caddyProxy"
  image = docker_image.caddyProxy.name
  restart = "unless-stopped"

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
    container_path = "/etc/caddy/Caddyfile"
    host_path = "/home/${var.adminUser}/config/caddyProxy/Caddyfile" # TODO: Add host path
  }
  volumes {
    container_path = "/data"
    host_path = "/home/${var.adminUser}/data/caddyProxy" # TODO: Add host path
  }
}
resource "docker_container" "vaultWarden" {
  provider = docker.orchestrator
  name = "vaultwarden"
  image = docker_image.vaultWarden.name
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.orchestratorInternal.name
  }

  ports {
    internal = 80
    external = 80
  }
  volumes {
    container_path = "/vaultwarden/data"
    host_path = "/home/${var.adminUser}/data/vaultwarden"
  }
  depends_on = [ docker_container.caddyProxy ]
  
}