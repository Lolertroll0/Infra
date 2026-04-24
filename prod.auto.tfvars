urls = {
  mainServer   = "" # TODO: add tailscale magic dns name
  orchestrator = "" # TODO: add tailscale magic dns name
  voicePipeline = "" # TODO: add tailscale magic dns name
}

# Global Vars
global = {
  adminUser = "" #TODO: add admin user (Setup GH secrets)
  adminEmail = "" #TODO: add admin email (Setup GH secrets) 
}

# Tailscale vars
tailscale = {
  tailscaleAPIKey = "" # TODO: Add tailscale API Key (Setup GH secrets)
  tailnet = "" # TODO: Add tailnet (Setup GH secrets)
}

proxmox = {
  proxmoxSecret = "" # TODO: Add proxmox secret (Setup GH secrets)
  proxmoxAPI = "" # TODO: Add proxmox API (Setup GH secrets)
  proxmoxTokenId = "" # TODO: Add proxmox token ID (Setup GH secrets)
  haosTemplate = "" # TODO: Add HAOS template name
  ezbkTemplate = "" # TODO: Add ezBookKeeping template name
}  
