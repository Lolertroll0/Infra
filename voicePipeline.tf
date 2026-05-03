resource "docker_network" "voicePipelineInternal" {
  provider   = docker.voicePipeline
  name       = "voicePipelineInternal"
  internal   = true
  depends_on = [null_resource.setup_voicePipelineEnvironment]
}

resource "null_resource" "setup_voicePipelineEnvironment" {
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
      "mkdir -p /home/${var.adminUser}/data/whisper/",
      "mkdir -p /home/${var.adminUser}/data/piper/",
      "mkdir -p /home/${var.adminUser}/data/ollama/"
    ]
    connection {
      type        = "ssh"
      host        = var.voicePipelinePrivateIp
      user        = var.adminUser
      private_key = file(var.voiceKey)
      timeout     = "1m"
    }
  }
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
    host_path      = "/home/${var.adminUser}/data/whisper"
  }
  networks_advanced {
    name = docker_network.voicePipelineInternal.name
  }
  depends_on = [null_resource.setup_voicePipelineEnvironment]
}

resource "docker_container" "piper" {
  provider = docker.voicePipeline
  name     = "piper"
  image    = docker_image.piper.name
  restart  = "unless-stopped"

  ports {
    internal = 10200
    external = 10200
  }
  volumes {
    container_path = "/data"
    host_path      = "/home/${var.adminUser}/data/piper"
  }
  networks_advanced {
    name = docker_network.voicePipelineInternal.name
  }
  depends_on = [null_resource.setup_voicePipelineEnvironment]
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
    host_path      = "/home/${var.adminUser}/data/ollama"
  }
  networks_advanced {
    name = docker_network.voicePipelineInternal.name
  }
  depends_on = [null_resource.setup_voicePipelineEnvironment]
}
