# Generate Tailscale auth keys
resource "tailscale_tailnet_key" "infraKeyMainServer" {
  reusable = true
  description = "Auth keys for main server nodes"
  tags = ["tag:mainServer"]
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

# resource "tailscale_tailnet_key" "infraKeyVoicePipeline" {
#   reusable = true
#   description = "Auth keys for voice nodes"
#   tags = ["tag:voice"]
#   preauthorized = true
#   ephemeral = false
# }

# Output Tailscale auth keys
output "TailscaleAuthKeyForMainServer" {
  value = tailscale_tailnet_key.infraKeyMainServer.key
  sensitive = true
  description = "Assign autorized Authkey to main server nodes and tag them as tag:mainServer"
}
output "TailscaleAuthKeyForOrchestrator" {
  value = tailscale_tailnet_key.infraKeyOrchestrator.key
  sensitive = true
  description = "Assign autorized Authkey to orchestrator nodes and tag them as tag:orchestrator"
}
