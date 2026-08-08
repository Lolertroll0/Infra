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
  host     = "ssh://${data.terraform_remote_state.infra.outputs.adminUser}@${data.terraform_remote_state.infra.outputs.mainServer}:22"
  ssh_opts = concat(data.terraform_remote_state.infra.outputs.mainKey != "" ? ["-i", data.terraform_remote_state.infra.outputs.mainKey] : [], ["-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null"])
}
provider "docker" {
  alias    = "orchestrator"
  host     = "ssh://${data.terraform_remote_state.infra.outputs.adminUser}@${data.terraform_remote_state.infra.outputs.orchestrator}:22"
  ssh_opts = concat(data.terraform_remote_state.infra.outputs.orchestratorKey != "" ? ["-i", data.terraform_remote_state.infra.outputs.orchestratorKey] : [], ["-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null"])
}

provider "docker" {
  alias    = "voicePipeline"
  host     = "ssh://${data.terraform_remote_state.infra.outputs.adminUser}@${data.terraform_remote_state.infra.outputs.voicePipeline}:22"
  ssh_opts = concat(data.terraform_remote_state.infra.outputs.voiceKey != "" ? ["-i", data.terraform_remote_state.infra.outputs.voiceKey] : [], ["-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null"])
}

provider "docker" {
  alias    = "otherServices"
  host     = "ssh://${data.terraform_remote_state.infra.outputs.adminUser}@${data.terraform_remote_state.infra.outputs.otherServicesIP}:22"
  ssh_opts = concat(data.terraform_remote_state.infra.outputs.otherServicesKey != "" ? ["-i", data.terraform_remote_state.infra.outputs.otherServicesKey] : [], ["-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null"])
}
