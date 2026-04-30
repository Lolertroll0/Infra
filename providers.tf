terraform {
  required_version = "1.15.0"

  cloud {
    organization = "Lolertroll-home-Server"
    workspaces {
      name = "distributed-homeserver"
    }
  }

  required_providers {
    docker = {
        source = "kreuzwerker/docker"
        version = "~> 4.0"
    }
    # proxmox = {
    #     source = "Telmate/proxmox"
    #     version = "~> 2.9"
    # }
    tailscale = {
        source = "tailscale/tailscale"
        version = "~> 0.28.0"
    }
    
  }
}

provider "docker" {
  alias = "mainServer"
  host = "ssh://${var.adminUser}@${var.mainServer}:22"
  # ssh_opts = ["-i ${var.mainKey}"]
}
provider "docker" {
  alias = "orchestrator"
  host = "ssh://${var.adminUser}@${var.orchestrator}:22"
  # ssh_opts = ["-i ${var.rp4Key}"]
}
provider "docker" {
  alias = "voicePipeline"
  host = "ssh://${var.adminUser}@${var.voicePipeline}:22"
  # ssh_opts = ["-i ${var.voiceKey}"]
}

# provider "proxmox" {
#   pm_api_url          = "${var.proxmoxAPI}"
#   pm_api_token_id     = "${var.proxmoxTokenId}"
#   pm_api_token_secret = "${var.proxmoxSecret}"
#   pm_tls_insecure     = true
# }
provider "tailscale" {
  api_key = "${var.tailscaleSecret}"
  tailnet = "${var.tailnet}"
}
