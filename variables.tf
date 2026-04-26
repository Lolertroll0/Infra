# Global variables
variable "adminUser" {
	type        = string
	description = "Global variables"
	sensitive   = true
}

variable "adminEmail" {
	type        = string
	description = "Global variables"
	sensitive   = true
}

# List of URLs for the docker providers
variable "mainServer" {
	description = "List of URLs for the docker providers"
	type        = string
}

variable "orchestrator" {
	description = "List of URLs for the docker providers"
	type        = string
}

variable "voicePipeline" {
	description = "List of URLs for the docker providers"
	type        = string
}

# SSH Keys for the docker providers
variable "mainKey" {
	type        = string
	sensitive   = true
}

variable "rp4Key" {
	type        = string
	sensitive   = true
}

variable "voiceKey" {
	type        = string
	sensitive   = true
}

# Tailscale variables
variable "tailscaleSecret" {
	type        = string
	sensitive   = true
	description = "Tailscale variables"
}

variable "tailnet" {
	type        = string
	sensitive   = false
	description = "Tailscale variables"
}

# Proxmox variables
variable "proxmoxSecret" {
	type        = string
	sensitive   = true
	description = "The secret for the Proxmox API - Used to spin up VMs"
}

variable "proxmoxAPI" {
	type        = string
	sensitive   = true
	description = "The secret for the Proxmox API - Used to spin up VMs"
}

variable "proxmoxTokenId" {
	type        = string
	sensitive   = true
	description = "The secret for the Proxmox API - Used to spin up VMs"
}

variable "haosTemplate" {
	type        = string
	sensitive   = false
	description = "The secret for the Proxmox API - Used to spin up VMs"
}

variable "ezbkTemplate" {
	type        = string
	sensitive   = false
	description = "The secret for the Proxmox API - Used to spin up VMs"
}