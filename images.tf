#Orchestrator Resources
resource "docker_image" "uptimeKuma" {
  provider = docker.orchestrator
  name = "louislam/uptime-kuma:2"
}
resource "docker_image" "caddyProxy" {
  provider = docker.orchestrator
  name = "caddy:alpine"
}
resource "docker_image" "vaultWarden" {
  provider = docker.orchestrator
  name = "dhi.io/vaultwarden:latest"
}

#Voice Pipeline Resources
resource "docker_image" "ollama" {
  provider = docker.voicePipeline
  name = "thelocallab/ollama-openwebui:latest"
}
resource "docker_image" "whisper" {
  provider = docker.voicePipeline
  name = "rhasspy/wyoming-whisper:3.1.0"
}
resource "docker_image" "piper" {
  provider = docker.voicePipeline
  name = "rhasspy/wyoming-piper:2.2.2"
}
