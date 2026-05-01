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
# variable "mainServer" {
# 	description = "List of URLs for the docker providers"
# 	type        = string
# }

# variable "orchestrator" {
# 	description = "List of URLs for the docker providers"
# 	type        = string
# }

# variable "voicePipeline" {
# 	description = "List of URLs for the docker providers"
# 	type        = string
# }

variable "rp4PrivateIp" {
	type        = string
	description = "Private IP of the RP4"
	sensitive   = false
}

variable "mainServerPrivateIp" {
	type        = string
	description = "Private IP of the Main Server"
	sensitive   = false
}

variable "voicePipelinePrivateIp" {
	type        = string
	description = "Private IP of the Voice Pipeline"
	sensitive   = false
}

# SSH Keys for the docker providers
# variable "mainKey" {
# 	type        = string
# 	sensitive   = true
# }

# variable "rp4Key" {
# 	type        = string
# 	sensitive   = true
# }

# variable "voiceKey" {
# 	type        = string
# 	sensitive   = true
# }

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

variable "tailscaleEphemeralKey" {
	type        = string
	sensitive   = true
	description = "TailscaleEphemeralKey for the RP4"
}

# # Proxmox variables
# variable "proxmoxSecret" {
# 	type        = string
# 	sensitive   = true
# 	description = "The secret for the Proxmox API - Used to spin up VMs"
# }

# variable "proxmoxAPI" {
# 	type        = string
# 	sensitive   = true
# 	description = "The secret for the Proxmox API - Used to spin up VMs"
# }

# variable "proxmoxTokenId" {
# 	type        = string
# 	sensitive   = true
# 	description = "The secret for the Proxmox API - Used to spin up VMs"
# }

# variable "haosTemplate" {
# 	type        = string
# 	sensitive   = false
# 	description = "The secret for the Proxmox API - Used to spin up VMs"
# }

# variable "ezbkTemplate" {
# 	type        = string
# 	sensitive   = false
# 	description = "The secret for the Proxmox API - Used to spin up VMs"
# }