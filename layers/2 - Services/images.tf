#Orchestrator Resources
resource "docker_image" "uptimeKuma" {
  provider = docker.orchestrator
  name     = "louislam/uptime-kuma:2"
}
resource "docker_image" "caddyProxy" {
  provider = docker.orchestrator
  name     = "caddy:2.7.6-alpine"
}
resource "docker_image" "vaultWarden" {
  provider = docker.orchestrator
  name     = "vaultwarden/server:1.37.1"
}

#Voice Pipeline Resources
# Note: thelocallab/ollama-openwebui is an unofficial combined image. 
# Consider migrating to official separate containers (ollama/ollama and open-webui/open-webui) to enable strict version pinning.
resource "docker_image" "ollama" {
  provider = docker.voicePipeline
  name     = "thelocallab/ollama-openwebui:latest"
}
resource "docker_image" "whisper" {
  provider = docker.voicePipeline
  name     = "rhasspy/wyoming-whisper:3.1.0"
}
resource "docker_image" "piper" {
  provider = docker.voicePipeline
  name     = "rhasspy/wyoming-piper:2.2.2"
}

# Main Server Resources
resource "docker_image" "ezbookkeeping" {
  provider = docker.otherServices
  name     = "mayswind/ezbookkeeping:1.5"
}

resource "docker_image" "firefly" {
  provider = docker.otherServices
  name     = "fireflyiii/core:version-6.6"
}

resource "docker_image" "firefly_db" {
  provider = docker.otherServices
  name     = "mariadb:11.4"
}

resource "docker_image" "duplicati" {
  provider = docker.orchestrator
  # Note: duplicati/duplicati uses complex beta tag naming (e.g. 2.0.8.1_beta_2024-05-07).
  # We use latest here to track stable/beta major 2, or you can manually pin to a specific date tag.
  name = "duplicati/duplicati:latest"
}

