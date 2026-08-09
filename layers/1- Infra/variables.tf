# --- ADMINISTRATIVE CREDENTIALS ---
variable "adminUser" {
  type      = string
  sensitive = true
}

variable "adminEmail" {
  type      = string
  sensitive = true
}

variable "adminPassword" {
  type      = string
  sensitive = true
}

# --- INFRASTRUCTURE NODE CONNECTIONS (IPs / Hostnames) ---
variable "mainServer" {
  type      = string
  sensitive = true
}

variable "orchestrator" {
  type      = string
  sensitive = true
}

variable "voicePipeline" {
  type      = string
  sensitive = true
}

variable "otherServicesIP" {
  type      = string
  sensitive = true
}

# --- SSH PRIVATE KEYS ---
variable "mainKey" {
  type      = string
  sensitive = true
}

variable "orchestratorKey" {
  type      = string
  sensitive = true
}

variable "voiceKey" {
  type      = string
  sensitive = true
}

variable "otherServicesKey" {
  type      = string
  sensitive = true
}

# --- TAILSCALE & SECRET INJECTION ---
variable "tailnet" {
  type      = string
  sensitive = true
}

variable "tailscaleSecret" {
  type      = string
  sensitive = true
}

variable "tailscaleMainAuthKey" {
  type      = string
  sensitive = true
}

variable "tailscaleOrchestratorAuthKey" {
  type      = string
  sensitive = true
}

variable "tailscaleVoiceAuthKey" {
  type      = string
  sensitive = true
}

variable "gDriveAuthID" {
  type      = string
  sensitive = true
}

# --- HARDWARE PASSTHROUGH ---
variable "homeAssistantUSB" {
  type = string
}

# --- PROXMOX AUTHENTICATION & STORAGE ---
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

variable "proxmoxStorage" {
  type        = string
  description = "The Proxmox storage pool name to use for VM virtual disks"
  default     = "local-lvm"
}

# --- VM TEMPLATES & NETWORKING ---
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

variable "homeAssistantIP" {
  type        = string
  sensitive   = true
  description = "IP address of the Home Assistant OS VM"
  default     = "192.168.1.103"
}

variable "networkGateway" {
  type        = string
  sensitive   = true
  description = "Network gateway for static IP configurations"
  default     = "192.168.1.1"
}

# --- PUBLIC KEYS ---
variable "homeAssistantKeyPublic" {
  type        = string
  sensitive   = true
  description = "Path to the SSH public key used for the Home Assistant OS VM"
  default     = ""
}

variable "otherServicesKeyPublic" {
  type        = string
  sensitive   = true
  description = "Path to the SSH public key used for the Other Services node"
  default     = ""
}

