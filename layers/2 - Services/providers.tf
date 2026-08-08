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
  host     = "ssh://${data.infra.outputs.adminUser}@${data.infra.outputs.mainServer}:22"
  ssh_opts = concat(data.infra.outputs.mainKey != "" ? ["-i", data.infra.outputs.mainKey] : [], ["-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null"])
}
provider "docker" {
  alias    = "orchestrator"
  host     = "ssh://${data.infra.outputs.adminUser}@${data.infra.outputs.orchestrator}:22"
  ssh_opts = concat(data.infra.outputs.orchestratorKey != "" ? ["-i", data.infra.outputs.orchestratorKey] : [], ["-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null"])
}

provider "docker" {
  alias    = "voicePipeline"
  host     = "ssh://${data.infra.outputs.adminUser}@${data.infra.outputs.voicePipeline}:22"
  ssh_opts = concat(data.infra.outputs.voiceKey != "" ? ["-i", data.infra.outputs.voiceKey] : [], ["-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null"])
}

provider "docker" {
  alias    = "otherServices"
  host     = "ssh://${data.infra.outputs.adminUser}@${data.infra.outputs.otherServicesIP}:22"
  ssh_opts = concat(data.infra.outputs.otherServicesKey != "" ? ["-i", data.infra.outputs.otherServicesKey] : [], ["-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null"])
}
