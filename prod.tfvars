urls = {
  mainServer   = "https://mainServer.${tailscale.tailnet}" 
  orchestrator = "https://rp4.${tailscale.tailnet}" 
  voicePipeline = "https://voice.${tailscale.tailnet}" 
}

# Global Vars
global = {
  adminUser = "" #TODO: add admin user (Setup GH secrets)
  adminEmail = "" #TODO: add admin email (Setup GH secrets) 
}

# Tailscale vars
tailscale = {
  tailscaleAPIKey = "" # TODO: Add tailscale API Key (Setup GH secrets)
  tailnet = "" # TODO: Add tailnet name (Setup GH secrets)
}

proxmox = {
  proxmoxSecret = "" # TODO: Add proxmox secret (Setup GH secrets)
  proxmoxAPI = "" # TODO: Add proxmox API (Setup GH secrets)
  proxmoxTokenId = "" # TODO: Add proxmox token ID (Setup GH secrets)
  
  haosTemplate = "" # TODO: Add HAOS template name
  ezbkTemplate = "" # TODO: Add ezBookKeeping template name
}  

ssh = {
  mainKey = "" # TODO: Add main location ssh key 
  rp4Key = "" # TODO: Add rp4 location ssh key 
  voiceKey = "" # TODO: Add voice location ssh key 
}
