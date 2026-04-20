resource "docker_network" "orchestratorInternal" {
  provider = docker.orchestrator
  name = "orchestratorInternal"
  internal = true
}

resource "docker_container" "uptimeKuma" {
  provider = docker.orchestrator
  name = "uptimeKuma"
  image = "louislam/uptime-kuma:2"
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
    host_path = "/home/${var.global.adminUser}/data/uptimeKuma" # TODO: Add host path
  }
  environment = [ "TZ=UTC-5" ]
  depends_on = [ docker_container.caddyProxy ]
  # TODO: add healthcheck config and logging config
  
}

resource "docker_container" "caddyProxy" {
  provider = docker.orchestrator
  name = "caddyProxy"
  image = "caddy:alpine"
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.orchestratorInternal.name
    capabilities = [ "NET_ADMIN" ]
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
    host_path = "/home/${var.global.adminUser}/config/caddyProxy/Caddyfile" # TODO: Add host path
  }
  volumes {
    container_path = "/data"
    host_path = "/home/${var.global.adminUser}/data/caddyProxy" # TODO: Add host path
  }
}

resource "docker_container" "vaultWarden" {
  provider = docker.orchestrator
  name = "vaultwarden"
  image = "dhi.io/vaultwarden:latest"
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
    host_path = "/home/${var.global.adminUser}/data/vaultwarden"
  }
  depends_on = [ docker_container.caddyProxy ]
  
}