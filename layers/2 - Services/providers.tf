terraform {
  required_version = ">= 1.15"

  cloud {
    organization = "Lolertroll-home-Server"
    workspaces {
      name = "services-layer"
    }
  }

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 4.0"
    }
  }
}

provider "docker" {
  alias    = "mainServer"
  host     = "ssh://${data.terraform_remote_state.outputs.adminUser}@${data.terraform_remote_state.outputs.mainServer}:22"
  ssh_opts = concat(data.terraform_remote_state.outputs.mainKey != "" ? ["-i", data.terraform_remote_state.outputs.mainKey] : [], ["-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null"])
}
provider "docker" {
  alias    = "orchestrator"
  host     = "ssh://${data.terraform_remote_state.outputs.adminUser}@${data.terraform_remote_state.outputs.orchestrator}:22"
  ssh_opts = concat(data.terraform_remote_state.outputs.orchestratorKey != "" ? ["-i", data.terraform_remote_state.outputs.orchestratorKey] : [], ["-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null"])
}

provider "docker" {
  alias    = "voicePipeline"
  host     = "ssh://${data.terraform_remote_state.outputs.adminUser}@${data.terraform_remote_state.outputs.voicePipeline}:22"
  ssh_opts = concat(data.terraform_remote_state.outputs.voiceKey != "" ? ["-i", data.terraform_remote_state.outputs.voiceKey] : [], ["-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null"])
}

provider "docker" {
  alias    = "otherServices"
  host     = "ssh://${data.terraform_remote_state.outputs.adminUser}@${data.terraform_remote_state.outputs.otherServicesIP}:22"
  ssh_opts = concat(data.terraform_remote_state.outputs.otherServicesKey != "" ? ["-i", data.terraform_remote_state.outputs.otherServicesKey] : [], ["-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null"])
}
