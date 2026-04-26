resource "docker_network" "voicePipelineInternal" {
  provider = docker.voicePipeline
  name = "voicePipelineInternal"
  internal = true
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