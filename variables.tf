variable "global" {
	type = object({
		adminUser = string
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
variable "LocalIP" {
	description = "List of IPs to inital configs on"
	type = object({
		mainServer = string
		orchestrator = string
		voicePipeline = string
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
	})
	sensitive = true
	description = "The secret for the Proxmox API - Used to spin up VMs"
}