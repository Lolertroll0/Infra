# Infrastructure-as-Code: Distributed Home Lab

This repository contains the Terraform configuration for a professional-grade, distributed home infrastructure. It manages resources across Proxmox virtual machines and remote Docker hosts, all interconnected via a **Zero Trust** Tailscale mesh network.

## 🚀 Project Overview

The project is currently transitioning from a simulated Vagrant environment to a **Physical Hardware Deployment**. The architecture is designed for high security, isolation, and automated observability.

### 🏗️ Architecture

The infrastructure is logically divided into three specialized environments:

1.  **Main Server (Proxmox / x86_64)**:
    *   **Home Assistant OS (HAOS)**: The heart of home automation, running as a dedicated appliance.
    *   **ezBookKeeping**: A financial tracking suite running in a Debian-based Docker container.
2.  **Orchestrator Node (Raspberry Pi 4)**:
    *   **Caddy Proxy**: Acts as the gateway, routing `*.ts.net` MagicDNS traffic to internal services.
    *   **Uptime Kuma**: Real-time monitoring and heartbeat tracking for all nodes.
    *   **Vaultwarden**: Self-hosted Bitwarden-compatible password management.
3.  **Voice & AI Pipeline**:
    *   **Ollama**: Local hosting for Large Language Models.
    *   **Whisper & Piper**: STT/TTS processing via the Wyoming protocol for private voice control.

## 🔒 Security & Networking

*   **Zero Trust**: No ports are opened on the router. All inter-node communication happens over **Tailscale**.
*   **MagicDNS**: Services are accessed via user-friendly names (e.g., `vaultwarden.rp4.your-tailnet.ts.net`).
*   **SSH Isolation**: All Docker providers connect over SSH using dedicated private keys, managed securely via CI/CD.

## 🤖 CI/CD & Automation

The project uses **GitHub Actions** for fully automated deployments:

*   **Continuous Deployment**: Pushing to the `main` branch triggers a Terraform Apply.
*   **Secret Management**: Sensitive data (API keys, SSH keys, passwords) is injected into Terraform via GitHub Secrets.
*   **Observability**: Success/Failure notifications are sent to **Discord**.
*   **Artifacts**: In the event of a failure, the last 500 lines of the Terraform log are captured and uploaded as an artifact for debugging.

## 📂 Repository Structure

*   `providers.tf`: Definition of Docker, Proxmox, and Tailscale providers.
*   `variables.tf`: Centrally managed variables with enhanced descriptions.
*   `mainServer.tf`: Proxmox VM definitions and Cloud-Init provisioning.
*   `rp4Orchestrator.tf`: Management services and Caddy configuration.
*   `voicePipeline.tf`: AI and Voice processing stack.
*   `caddyfile`: Reverse proxy rules with Tailnet placeholder substitution.

## 🛠️ Local Development

For local testing, use a `local.tfvars` file (which is gitignored). 

```hcl
# Example local.tfvars
adminUser     = "your-user"
proxmoxAPI    = "https://proxmox.local:8006/api2/json"
tailscaleMainAuthKey = "tskey-auth-..."
```

To initialize:
```bash
terraform init
terraform plan -var-file="local.tfvars"
```
