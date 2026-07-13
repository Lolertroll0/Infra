resource "docker_network" "voicePipelineInternal" {
  provider   = docker.voicePipeline
  name       = "voicePipelineInternal"
  internal   = false
  depends_on = [null_resource.setup_voicePipelineEnvironment]
}

resource "null_resource" "setup_voicePipelineEnvironment" {
  triggers = {
    host_ip         = var.voicePipeline
    adminUser       = var.adminUser
    voiceKey        = var.voiceKey
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
      "if ! sudo tailscale status >/dev/null 2>&1; then sudo tailscale up --authkey=${var.tailscaleVoiceAuthKey} --ssh --accept-risk=lose-ssh; fi",
      "mkdir -p ${local.data_dir}/whisper/",
      "mkdir -p ${local.data_dir}/piper/",
      "mkdir -p ${local.data_dir}/ollama/"
    ]
    connection {
      type        = "ssh"
      host        = var.voicePipeline
      user        = var.adminUser
      private_key = var.voiceKey != "" ? file(var.voiceKey) : null
      timeout     = "10m"
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
    host_path      = "${local.data_dir}/whisper"
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
    host_path      = "${local.data_dir}/ollama"
  }
  networks_advanced {
    name = docker_network.voicePipelineInternal.name
  }
  depends_on = [null_resource.setup_voicePipelineEnvironment]
}
