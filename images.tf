#Orchestrator Resources
resource "docker_image" "uptimeKuma" {
  provider   = docker.orchestrator
  name       = "louislam/uptime-kuma:2"
  depends_on = [null_resource.setup_OrchestratorEnvironment]
}
resource "docker_image" "caddyProxy" {
  provider   = docker.orchestrator
  name       = "caddy:alpine"
  depends_on = [null_resource.setup_OrchestratorEnvironment]
}
resource "docker_image" "vaultWarden" {
  provider   = docker.orchestrator
  name       = "vaultwarden/server:latest"
  depends_on = [null_resource.setup_OrchestratorEnvironment]
}

#Voice Pipeline Resources
resource "docker_image" "ollama" {
  provider   = docker.voicePipeline
  name       = "thelocallab/ollama-openwebui:latest"
  depends_on = [null_resource.setup_voicePipelineEnvironment]
}
resource "docker_image" "whisper" {
  provider   = docker.voicePipeline
  name       = "rhasspy/wyoming-whisper:3.1.0"
  depends_on = [null_resource.setup_voicePipelineEnvironment]
}
resource "docker_image" "piper" {
  provider   = docker.voicePipeline
  name       = "rhasspy/wyoming-piper:2.2.2"
  depends_on = [null_resource.setup_voicePipelineEnvironment]
}
