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

import {
  to       = docker_network.voicePipelineInternal
  id       = "voicePipelineInternal"
  provider = docker.voicePipeline
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
      user        = local.infra.adminUser
      private_key = local.infra.ssh_private_key
      host        = local.infra.otherServicesIP
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

resource "docker_container" "whisper" {
  provider = docker.voicePipeline
  name     = "whisper"
  image    = docker_image.whisper.name
  restart  = "unless-stopped"

  ports {
    internal = 10300
    external = 10300
  }
  volumes {
    container_path = "/data"
    host_path      = "${local.data_dir}/whisper"
  }
  networks_advanced {
    name = docker_network.voicePipelineInternal.name
  }
}

resource "docker_container" "piper" {
  provider = docker.voicePipeline
  name     = "piper"
  image    = docker_image.piper.name
  command  = ["--voice", "en_US-lessac-medium"]
  restart  = "unless-stopped"

  ports {
    internal = 10200
    external = 10200
  }
  volumes {
    container_path = "/data"
    host_path      = "${local.data_dir}/piper"
  }
  networks_advanced {
    name = docker_network.voicePipelineInternal.name
  }
}

resource "docker_container" "ollama" {
  provider = docker.voicePipeline
  name     = "ollama"
  image    = docker_image.ollama.name
  restart  = "unless-stopped"

  ports {
    internal = 11434
    external = 11434
  }
  ports {
    internal = 8080
    external = 8080
  }

  volumes {
    container_path = "/data"
    host_path      = "${local.data_dir}/ollama"
  }
  networks_advanced {
    name = docker_network.voicePipelineInternal.name
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

resource "docker_network" "voicePipelineInternal" {
  provider = docker.voicePipeline
  name     = "voicePipelineInternal"
  internal = false
}

