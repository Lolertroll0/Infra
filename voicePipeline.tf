resource "docker_network" "voicePipelineInternal" {
  provider = docker.voicePipeline
  name = "voicePipelineInternal"
  internal = true
}

resource "null_resource" "setup_voicePipelineEnvironment" {
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
      host        = var.voicePipelinePrivateIp
      user        = var.adminUser
      private_key = file("C:/Users/JhonVelasquez/.ssh/voicePipeline")
      timeout     = "1m"
    }
  }
}

resource "docker_container" "whisper" {
  provider = docker.voicePipeline
  name = "whisper"
  image = docker_image.whisper.name
  restart = "unless-stopped"

  ports {
    internal = 10300
    external = 10300
  }
  volumes {
    container_path = "/data"
    host_path = "/home/${var.adminUser}/data/whisper"
  }
  networks_advanced {
    name = docker_network.voicePipelineInternal.name
  }
}

resource "docker_container" "piper" {
  provider = docker.voicePipeline
  name = "piper"
  image = docker_image.piper.name
  restart = "unless-stopped"

  ports {
    internal = 10200
    external = 10200
  }
  volumes {
    container_path = "/data"
    host_path = "/home/${var.adminUser}/data/piper"
  }
  networks_advanced {
    name = docker_network.voicePipelineInternal.name
  }
}

resource "docker_container" "ollama" {
  provider = docker.voicePipeline
  name = "ollama"
  image = docker_image.ollama.name
  restart = "unless-stopped"

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
    host_path = "/home/${var.adminUser}/data/ollama"
  }
  networks_advanced {
    name = docker_network.voicePipelineInternal.name
  }
}