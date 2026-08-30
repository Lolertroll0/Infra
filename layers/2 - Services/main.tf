# Import existing Docker networks into Layer 2 state
import {
  to       = docker_network.orchestratorInternal
  id       = "orchestratorInternal"
  provider = docker.orchestrator
}

import {
  to       = docker_network.financial_assistant_net
  id       = "financial_assistant_net"
  provider = docker.otherServices
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
    docker_container.caddyProxy
  ]
}

resource "docker_container" "caddyProxy" {
  provider = docker.orchestrator
  name     = "caddyProxy"
  image    = docker_image.caddyProxy.name
  restart  = "unless-stopped"
  dns      = ["100.100.100.100"]

  env = [
    "CADDYFILE_HASH=${md5(file("${path.module}/../../caddyfile"))}"
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
    docker_container.caddyProxy
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
    docker_container.caddyProxy
  ]
  env = [
    "DUPLICATI__WEBSERVICE_PASSWORD=${data.terraform_remote_state.infra.outputs.adminPassword}"
  ]
}

resource "docker_container" "financial_assistant" {
  name     = "financial_assistant"
  image    = docker_image.firefly.name
  provider = docker.otherServices

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

resource "null_resource" "firefly_db_migration" {
  depends_on = [
    docker_container.financial_assistant,
    docker_container.financial_assistant_db
  ]

  triggers = {
    always_run = timestamp()
  }

  provisioner "remote-exec" {
    inline = [
      "sleep 5",
      "docker exec financial_assistant php artisan migrate --force",
      "docker exec financial_assistant php artisan passport:keys --force || true"
    ]

    connection {
      type        = "ssh"
      user        = data.terraform_remote_state.infra.outputs.adminUser
      private_key = data.terraform_remote_state.infra.outputs.otherServicesKey != "" ? data.terraform_remote_state.infra.outputs.otherServicesKey : null
      password    = data.terraform_remote_state.infra.outputs.adminPassword
      host        = data.terraform_remote_state.infra.outputs.otherServicesIP
    }
  }
}

resource "docker_container" "ezbookkeeping" {
  name     = "ezbookkeeping"
  image    = docker_image.ezbookkeeping.name
  provider = docker.otherServices
  restart  = "unless-stopped"

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
  name     = "financial_assistant_db"
  image    = docker_image.firefly_db.name
  provider = docker.otherServices
  restart  = "unless-stopped"

  networks_advanced {
    name    = docker_network.financial_assistant_net.name
    aliases = ["db", "financial_assistant_db"]
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
    content = replace(<<-EOF
        #!/bin/bash
        set -a
        source /run/secrets/.db.env
        set +a
        exec /usr/local/bin/docker-entrypoint.sh mariadbd
        EOF
    , "\r", "")
    file       = "/custom-entrypoint.sh"
    executable = true
  }

  entrypoint = ["/custom-entrypoint.sh"]
}

resource "docker_container" "open_webui" {
  provider = docker.voicePipeline
  name     = "open-webui"
  image    = docker_image.open_webui.name
  restart  = "unless-stopped"

  ports {
    internal = 8080
    external = 8080
  }

  env = [
    "OPENAI_API_BASE_URL=http://host.docker.internal:1234/v1",
    "OPENAI_API_KEY=lm-studio",
    "WEBUI_AUTH=false",
    "ENABLE_OLLAMA_API=false"
  ]

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

  volumes {
    container_path = "/app/backend/data"
    host_path      = "${local.data_dir}/open-webui"
  }
}

# Networks 
resource "docker_network" "orchestratorInternal" {
  provider = docker.orchestrator
  name     = "orchestratorInternal"
  internal = false
}

resource "docker_network" "financial_assistant_net" {
  provider = docker.otherServices
  name     = "financial_assistant_net"
  internal = false
}


