terraform {
  required_version = ">= 1.15"

  cloud {
    organization = "Lolertroll-home-Server"
    workspaces {
      name = "infrastructure-layer"
    }
  }

  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc07"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.28.0"
    }

  }
}

provider "proxmox" {
  pm_api_url          = var.proxmoxAPI
  pm_api_token_id     = var.proxmoxTokenId
  pm_api_token_secret = var.proxmoxSecret
  pm_tls_insecure     = true
}
provider "tailscale" {
  api_key = var.tailscaleSecret
  tailnet = var.tailnet
}
