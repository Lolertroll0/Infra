variable "global" {
	type = object({
		adminUser = string
		adminEmail = string
	})
	description = "Global variables"
	sensitive = true
}
# List of URLs for the docker providers
variable "urls" {
	description = "List of URLs for the docker providers"
	type = object({
		mainServer = string
		orchestrator = string
		voicePipeline = string
	})
}
variable "ssh" {
	type = object({
		mainKey = string 
		rp4Key = string
		voiceKey = string
	})
}
variable "tailscale" {
	type = object({
		tailscaleSecret = string
		tailnet = string
	})
	sensitive = true
	description = "Tailscale variables"
}

# Proxmox variables
variable "proxmox" {
	type = object({
		proxmoxSecret = string
		proxmoxAPI = string
		proxmoxTokenId = string
		haosTemplate = string
		ezbkTemplate = string
	})
	sensitive = true
	description = "The secret for the Proxmox API - Used to spin up VMs"
}