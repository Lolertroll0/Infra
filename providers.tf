terraform {
  required_providers {
    docker = {
        source = "kreuzwerker/docker"
        version = "~> 4.0"
    }
    proxmox = {
        source = "Telmate/proxmox"
        version = "~> 2.9"
    }
    tailscale = {
        source = "tailscale/tailscale"
        version = "~> 0.27.0"
    }
  }
}

provider "docker" {
  alias = "mainServer"
  host = "ssh://${var.global.adminUser}@${var.urls.mainServer}:22"
}
provider "docker" {
  alias = "orchestrator"
  host = "ssh://${var.global.adminUser}@${var.urls.orchestrator}:22"
}
provider "docker" {
  alias = "voicePipeline"
  host = "ssh://${var.global.adminUser}@${var.urls.voicePipeline}:22"
}
provider "proxmox" {
  pm_api_url          = "${var.proxmox.proxmoxAPI}"
  pm_api_token_id     = "${var.proxmox.proxmoxTokenId}"
  pm_api_token_secret = "${var.proxmox.proxmoxSecret}"
  pm_tls_insecure     = true
}
provider "tailscale" {
  api_key = "${var.tailscale.tailscaleAPIKey}"
  tailnet = "${var.tailscale.tailnet}"
}
