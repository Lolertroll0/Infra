# Generate Tailscale auth keys
resource "tailscale_tailnet_key" "infraKeyServer" {
  reusable = true
  description = "Auth keys for server nodes"
  tags = ["tag:automation"]
  preauthorized = true
  ephemeral = false
}

resource "tailscale_tailnet_key" "infraKeyOrchestrator" {
  reusable = true
  description = "Auth keys for orchestrator nodes"
  tags = ["tag:orchestrator"]
  preauthorized = true
  ephemeral = false
}

resource "tailscale_tailnet_key" "infraKeyVoicePipeline" {
  reusable = true
  description = "Auth keys for voice nodes"
  tags = ["tag:voice"]
  preauthorized = true
  ephemeral = false
}

# Output Tailscale auth keys
output "TailscaleAuthKeyForServer" {
  value = tailscale_tailnet_key.infraKeyServer.key
  sensitive = true
  description = "Assign autorized Authkey to server nodes and tag them as tag:server"
}
output "TailscaleAuthKeyForOrchestrator" {
  value = tailscale_tailnet_key.infraKeyOrchestrator.key
  sensitive = true
  description = "Assign autorized Authkey to orchestrator nodes and tag them as tag:orchestrator"
}
