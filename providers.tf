terraform {
  required_version = ">= 1.15"

  cloud {
    organization = "Lolertroll-home-Server"
    workspaces {
      name = "distributed-homeserver"
    }
  }

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 4.0"
    }
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

provider "docker" {
  alias    = "mainServer"
  host     = "ssh://${var.adminUser}@${var.mainServer}:22"
  ssh_opts = concat(var.mainKey != "" ? ["-i", var.mainKey] : [], ["-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null"])
}
provider "docker" {
  alias    = "orchestrator"
  host     = "ssh://${var.adminUser}@${var.orchestrator}:22"
  ssh_opts = concat(var.orchestratorKey != "" ? ["-i", var.orchestratorKey] : [], ["-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null"])
}

provider "docker" {
  alias    = "voicePipeline"
  host     = "ssh://${var.adminUser}@${var.voicePipeline}:22"
  ssh_opts = concat(var.voiceKey != "" ? ["-i", var.voiceKey] : [], ["-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null"])
}

provider "docker" {
  alias    = "otherServices"
  host     = "ssh://${var.adminUser}@${var.otherServicesIP}:22"
  ssh_opts = concat(var.otherServicesKey != "" ? ["-i", var.otherServicesKey] : [], ["-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null"])
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
