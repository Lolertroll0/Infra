# Administrative variables
variable "adminUser" {
  type        = string
  description = "The administrative username for the infrastructure nodes"
  sensitive   = true
}

variable "adminEmail" {
  type        = string
  description = "Administrative email for notifications and SSL certificate registration"
  sensitive   = true
}

variable "adminPassword" {
  type        = string
  description = "The administrative password for the infrastructure nodes"
  sensitive   = true
}

# List of URLs for the docker providers (magicDNS)
# These will be used almost all the time
variable "mainServer" {
  description = "magicDNS name of the Main Server"
  type        = string
}
variable "orchestrator" {
  description = "magicDNS name of the Orchestrator Server"
  type        = string
}
variable "voicePipeline" {
  description = "magicDNS name of the Voice Pipeline Server"
  type        = string
}
variable "otherServicesIP" {
  description = "IP address of the Other Services Server (Main Server)"
  type        = string
  default     = "192.168.1.113"
}
variable "homeAssistantIP" {
  description = "IP address of the Home Assistant OS VM"
  type        = string
  default     = "192.168.1.103"
}
variable "networkGateway" {
  description = "Network gateway for the static IP configuration"
  type        = string
  default     = "192.168.1.1"
}

# SSH Private Keys for the docker providers
# Introduced SSH Public keys to prevent auth failures when the orchestrator is down
variable "mainKey" {
  type        = string
  sensitive   = true
  description = "Path to the SSH private key used for the Main Server"
}
variable "mainKeyPublic" {
  type        = string
  sensitive   = true
  description = "Path to the SSH public key used for the Main Server"
}

variable "orchestratorKey" {
  type        = string
  sensitive   = true
  description = "Path to the SSH private key used for the Orchestrator node"
}

variable "orchestratorKeyPublic" {
  type        = string
  sensitive   = true
  description = "Path to the SSH public key used for the Orchestrator node"
}

variable "voiceKey" {
  type        = string
  sensitive   = true
  description = "Path to the SSH private key used for the Voice Pipeline node"
}

variable "voiceKeyPublic" {
  type        = string
  sensitive   = true
  description = "Path to the SSH public key used for the Voice Pipeline node"
}

variable "otherServicesKey" {
  type        = string
  sensitive   = true
  description = "Path to the SSH private key used for the Other Services node"
}

variable "otherServicesKeyPublic" {
  type        = string
  sensitive   = true
  description = "Path to the SSH public key used for the Other Services node"
}

variable "homeAssistantKey" {
  type        = string
  sensitive   = true
  description = "Path to the SSH private key used for the Home Assistant OS VM"
}

variable "homeAssistantKeyPublic" {
  type        = string
  sensitive   = true
  description = "Path to the SSH public key used for the Home Assistant OS VM"
}

# Tailscale variables
# Introduced auth keys for each node
# These keys has Ephemeral, pre-authorized and resuable characteristics
variable "tailscaleSecret" {
  type        = string
  sensitive   = true
  description = "Tailscale variables"
}
variable "tailnet" {
  type        = string
  sensitive   = false
  description = "Tailnet name"
}
variable "tailscaleOrchestratorAuthKey" {
  type        = string
  sensitive   = true
  description = "Tailscale auth key for the Orchestrator node"
}
variable "tailscaleMainAuthKey" {
  type        = string
  sensitive   = true
  description = "Tailscale auth key for the Main node"
}
variable "tailscaleVoiceAuthKey" {
  type        = string
  sensitive   = true
  description = "Tailscale auth key for the Voice node"
}

# Proxmox variables
# These variables are used to authenticate with Proxmox
variable "proxmoxSecret" {
  type        = string
  sensitive   = true
  description = "The API Token Secret for Proxmox authentication"
}

variable "proxmoxAPI" {
  type        = string
  sensitive   = true
  description = "The full API URL for Proxmox (e.g., https://192.168.1.100:8006/api2/json)"
}

variable "proxmoxTokenId" {
  type        = string
  sensitive   = true
  description = "The API Token ID for Proxmox (e.g., root@pam!tokenname)"
}

# VM Template variables
variable "haosTemplate" {
  type        = string
  sensitive   = false
  description = "The name or ID of the Proxmox template to use for the Home Assistant OS VM"
}
variable "ezbkTemplate" {
  type        = string
  sensitive   = false
  description = "The name or ID of the Proxmox template to use for the ezBookKeeping Docker host"
}

variable "proxmoxStorage" {
  type        = string
  description = "The Proxmox storage pool name to use for VM virtual disks"
  default     = "local-lvm"
}

variable "homeAssistantUSB" {
  type        = string
  description = "The VendorID:ProductID of the physical USB device to attach to Home Assistant OS VM (e.g. 1a86:7523)"
  default     = ""
}

