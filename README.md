# Infrastructure Repository

This repository contains the Terraform configuration for a distributed home lab or private infrastructure. It provisions resources across Proxmox VMs and Docker hosts, all securely connected and managed via a Tailscale mesh network.

## Architecture & Environments

The infrastructure is logically divided into three main nodes/environments:

1. **Main Server (Proxmox)**: Hosts primary virtual machines.
   - **Home Assistant OS**: Main home automation server.
   - **ezBookKeeping**: Financial and bookkeeping application.
2. **Orchestrator (Docker on a Raspberry Pi / rp4)**: Runs core management and utility services.
   - **Caddy**: Reverse proxy for routing traffic across the tailnet to the various services.
   - **Uptime Kuma**: Monitoring and uptime tracking.
   - **Vaultwarden**: Password manager.
3. **Voice Pipeline (Docker)**: Dedicated host for voice and AI processing.
   - **Ollama (+ Open WebUI)**: Local LLM hosting and chat interface.
   - **Whisper**: Speech-to-Text (STT) via Wyoming protocol.
   - **Piper**: Text-to-Speech (TTS) via Wyoming protocol.

## Repository Files

### Core Terraform Files

- **`providers.tf`**: Configures the necessary Terraform providers (`kreuzwerker/docker`, `Telmate/proxmox`, `tailscale/tailscale`). It also establishes SSH connections to the various remote Docker hosts.
- **`variables.tf`**: Defines the expected input variables for the configuration, including credentials, URLs, and SSH keys.
- **`prod.auto.tfvars`**: Contains the actual variable values for the production environment. Includes URLs, Tailscale API keys, Proxmox secrets, and paths to SSH keys. *(Note: Secrets are meant to be injected via CI/CD like GitHub Actions).*

### Service Provisioning

- **`mainServer.tf`**: Provisions the Proxmox Virtual Machines (`HomeAssistantOS` and `ezBookKeeping`) by cloning existing templates.wwww
- **`rp4Orchestrator.tf`**: Deploys the Docker network and containers for the Orchestrator node (`uptimeKuma`, `caddyProxy`, `vaultwarden`).
- **`voicePipeline.tf`**: Deploys the Docker network and containers for the Voice Pipeline node (`whisper`, `piper`, `ollama`).
- **`images.tf`**: Declares all the Docker images required by the orchestrator and voice pipeline containers.

### Networking & Access Control

- **`caddyfile`**: The Caddy configuration file that maps `*.ts.net` Tailscale subdomains to their respective internal services and ports.
- **`tailscaleKeyGen.tf`**: Generates reusable, pre-authorized Tailscale auth keys to easily onboard and tag new nodes (`tag:mainServer`, `tag:orchestrator`).
- **`tailscalePolicy.tf`**: Defines the Tailscale ACLs, dictating which nodes and users can access specific ports/services, as well as managing Tailscale SSH access rules.
