# Infrastructure-as-Code: Distributed Home Lab

This repository contains the Terraform configuration for a professional-grade, distributed home infrastructure. It manages resources across Proxmox virtual machines and remote Docker hosts, all interconnected via a **Zero Trust** Tailscale mesh network.

## 🚀 Project Overview & Current State

The project has transitioned from a simulated Vagrant environment to a **Physical Hardware Deployment**. The architecture is designed for high security, isolation, and automated observability, running across physical x86 hardware (Proxmox host and dedicated mini PC).

### 🛠️ Technologies Used
*   **Infrastructure as Code:** Terraform
*   **Virtualization & Orchestration:** Proxmox VE, Docker
*   **Networking & Security:** Tailscale (Mesh VPN, MagicDNS, Tailscale SSH), Caddy (Reverse Proxy)
*   **CI/CD & Automation:** GitHub Actions, Bash Scripts
*   **Core Services:** Home Assistant OS, Uptime Kuma, Vaultwarden, Ollama, Whisper, Piper, ezBookKeeping

### 🏗️ Architecture

The infrastructure is logically divided into three specialized environments:

1.  **Main Server (Proxmox / x86_64)**:
    *   **Home Assistant OS (HAOS)**: The heart of home automation, running as a dedicated appliance.
    *   **ezBookKeeping**: A financial tracking suite running in a Debian-based Docker container.
2.  **Orchestrator Node (Mini PC / x86_64)**:
    *   **Caddy Proxy**: Acts as the gateway, routing `*.ts.net` MagicDNS traffic to internal services via HTTP/HTTPS.
    *   **Uptime Kuma**: Real-time monitoring and heartbeat tracking for all nodes.
    *   **Vaultwarden**: Self-hosted Bitwarden-compatible password management.
3.  **Voice & AI Pipeline**:
    *   **Ollama**: Local hosting for Large Language Models.
    *   **Whisper & Piper**: STT/TTS processing via the Wyoming protocol for private voice control.

## 🔒 Security & Networking

*   **Zero Trust**: No ports are opened on the router. All inter-node communication happens over **Tailscale**.
*   **MagicDNS**: Services are accessed via user-friendly names (e.g., `vaultwarden.orchestrator.your-tailnet.ts.net`).
*   **SSH Isolation**: All nodes use Tailscale SSH for secure, keyless administrative access. Docker providers connect over SSH using dedicated private keys, managed securely via CI/CD.

## 🤖 CI/CD & Automation

The project uses **GitHub Actions** for fully automated, predictable deployments:

*   **Plan-then-Apply**: The deployment workflow generates a `tfplan` artifact first, and applies that exact file to guarantee consistency between what is planned and what is deployed.
*   **Key Rotation**: Tailscale Auth Keys are automatically rotated via GitHub Actions (`regenerateKeys.yml`) using a Bash script (`regenerate-key.sh`) authenticated via Tailscale OAuth.
*   **Secret Management**: Sensitive data is tracked via an `env.template` and injected into Terraform via GitHub Secrets. Local `.env` files are `.gitignored`.
*   **Observability**: Success/Failure notifications and logs are sent to **Discord**.

## 🧠 Agent Context & Architectural Learnings

*Note for future AI Agents or Contributors reviewing this repository:*

1.  **SSH vs. Proxying**: Caddy is configured exclusively as an HTTP/HTTPS reverse proxy. **Do not attempt to route raw SSH traffic through Caddy** (without a layer4 plugin). SSH access must be done directly via Tailscale MagicDNS or Tailscale SSH.
2.  **Provider Hostnames**: The Docker Terraform provider uses **Full Tailscale MagicDNS names** (e.g., `ssh://user@mainServer.tailnet.ts.net:22`) for reliable routing across the Tailnet, avoiding volatile IP addresses.
3.  **Lifecycle Management (Destroy)**: While Terraform's `docker` provider handles container teardown, the `null_resource` blocks responsible for initial node setup require a specific `destroy` provisioner that runs `sudo tailscale logout`. This ensures offline nodes are cleanly removed from the Tailscale registry when infrastructure is destroyed.
4.  **Provisioning Idempotency**: Rely on native OS idempotency where possible. For example, use `mkdir -p` in `remote-exec` blocks rather than complex shell `if/else` checks to create configuration directories.
5.  **Tailscale Authentication**: Automated interactions with the Tailscale API (like key rotation) utilize **OAuth Clients** rather than Personal Access Tokens. This enforces the Principle of Least Privilege and ties the automation to a service account rather than a human user.

## 📂 Repository Structure

*   `providers.tf`: Definition of Docker, Proxmox, and Tailscale providers.
*   `variables.tf`: Centrally managed variables with enhanced descriptions.
*   `mainServer.tf`: Proxmox VM definitions and Cloud-Init provisioning.
*   `orchestrator.tf`: Management services and Caddy configuration.
*   `voicePipeline.tf`: AI and Voice processing stack.
*   `caddyfile`: Reverse proxy rules with Tailnet placeholder substitution.
*   `env.template`: Master list of required environment variables and secrets.
*   `scripts/regenerate-key.sh`: Automated Tailscale key rotation logic.
