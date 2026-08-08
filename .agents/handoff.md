# Infra Project Handoff

This document summarizes the current state, goals, and next steps for the `Lolertroll0/Infra` repository (branch `stage`). It is intended as context for future work by the owner or by an AI/code agent.

---

## Project Goal

Build a professional-grade, **distributed home lab** managed entirely via **Infrastructure as Code (Terraform)**, focusing on:

- Practicing DevOps skills: Terraform, multi-provider setups (Proxmox, Docker, Tailscale), CI/CD with GitHub Actions.
- Applying **Zero Trust** and secure networking using **Tailscale** (MagicDNS, ACLs, Tailscale SSH) and **Caddy** as an HTTPS reverse proxy.
- Designing an architecture that spans **physical x86 (Proxmox)** and dedicated x86 Mini PC nodes, with clear responsibility boundaries.
- Implementing **SRE-style practices**: reproducible deployments, key rotation, controlled destroy behavior (e.g., Tailscale logout), multi-state remote state sharing, and backup/recovery workflows.
- Using this home lab as a learning vehicle for moving from QA to DevOps/SRE engineering.

---

## Current Architecture & State

### High-level topology

- **Main Server (Proxmox / x86)**
  - Proxmox node hosting:
    - `HomeAssistantOS` VM (appliance-style Home Assistant OS).
    - `ezBookKeeping` VM for running Dockerized Firefly III and legacy ezBookKeeping.
  - Terraform manages VMs via the Proxmox provider and uses cloud-init for the ezBookKeeping VM.

- **Orchestrator Node (Mini PC / x86_64)**
  - Acts as the **HTTP(S) entry point** into the tailnet services.
  - Runs Docker with:
    - **Caddy** as a reverse proxy routing services via subdomain host headers.
    - **Uptime Kuma** for monitoring/heartbeats.
    - **Vaultwarden** for password management.
    - **Duplicati** for state/volume backup operations.
  - Uses a dedicated internal Docker network for orchestrator services.

- **Voice & AI Pipeline Node**
  - Separate node dedicated to AI/voice workloads.
  - Runs Docker with:
    - **Ollama** for LLMs.
    - **Whisper** (STT) and **Piper** (TTS) via Wyoming protocol.
  - Uses its own internal Docker network.

- **Networking & security**
  - All nodes join the same **Tailscale tailnet**; no router port forwarding.
  - Services are accessed by consumer devices on Tailscale via subdomains:
    - `vaultwarden.${tailnet}`
    - `uptime-kuma.${tailnet}`
    - `homeassistant.${tailnet}`
  - **Tailscale** on the orchestrator host terminates TLS for the Virtual Services (`svc:vaultwarden`, `svc:uptime-kuma`, `svc:homeassistant`, `svc:ezbk`) and forwards requests to Caddy on local port 80.
  - **Caddy** inspects the Host header and reverse-proxies matching hosts to local containers or remote nodes.
  - **Tailscale ACLs** and tags define which nodes and tags can talk to which ports, plus Tailscale SSH access rules. CI runner (`tag:ci`) is restricted to non-root `adminUser` access.

---

### Layered Multi-State Architecture (`layers/`)

The repository has been refactored into a **Layered Architecture (Option B)** with **HCP Remote State Sharing (Approach A)**:

```text
layers/
├── 1- Infra/                    # Infrastructure Layer (HCP Workspace: infrastructure-layer)
│   ├── main.tf                  # Proxmox VMs & null_resource host provisioning
│   ├── providers.tf             # Proxmox & Tailscale providers
│   ├── variables.tf             # Hardware & Tailscale credentials
│   ├── outputs.tf               # Node IPs, adminUser, SSH key paths exported to HCP State
│   ├── locals.tf                # Common base directory patterns
│   └── tailscalePolicy.tf       # Tailscale ACLs & SSH authorization policy
│
└── 2 - Services/                # Application Layer (HCP Workspace: services-layer)
    ├── data.tf                  # Dynamic data binding to "infrastructure-layer" HCP state
    ├── providers.tf             # Docker providers dynamically targeted via remote state outputs
    ├── images.tf                # All docker_image definitions with pinned versions
    ├── locals.tf                # Container base/data/config directory paths
    └── main.tf                  # All docker_container, docker_network, & docker_volume resources
```

---

### Deployment Status & Recent Milestones

- **Layered Refactor Complete**: Successfully decoupled physical VM / OS provisioning (`1- Infra`) from container application management (`2 - Services`).
- **HCP Remote State Integration**: Layer 2 reads all node connection IPs, credentials, and SSH keys dynamically from Layer 1's `outputs.tf` via `data.terraform_remote_state.infra.outputs`.
- **Firefly III Migration**: Deployed Firefly III alongside legacy ezBookKeeping on port 8081. Restored encrypted database secrets from Duplicati backups using `scripts/ff3-vars.sh` over Tailscale SSH without exposing secrets in `.tfstate`.
- **Security Validation Hardening**: Ran `/sec-validation`. Restricted `tag:ci` SSH permissions to non-root `adminUser` in `tailscalePolicy.tf`. Docker image tags pinned to immutable releases (`fireflyiii/core:version-6.6`, `mariadb:11.4`, `vaultwarden/server:1.37.1`).
- **Docker Provider Assignment**: All 10 application containers in `layers/2 - Services/main.tf` explicitly target their corresponding SSH Docker providers (`docker.orchestrator`, `docker.otherServices`, `docker.voicePipeline`).

---

## TODOs / Next Steps

### Core Infrastructure & Cleanup
- [x] Refactor monolith into `layers/1- Infra/` and `layers/2 - Services/`.
- [x] Configure HCP Remote State data source bindings in Layer 2.
- [ ] Set up HCP Terraform Run Triggers so an apply in `infrastructure-layer` automatically triggers a plan in `services-layer`.
- [ ] Remove legacy root-level `.tf` files (`images.tf`, `mainServer.tf`, `orchestrator.tf`, `providers.tf`, `voicePipeline.tf`, `tailscalePolicy.tf`) after confirming clean plan in both layers.

### Data Migration & Application Stack
- [x] Deploy Firefly III container stack on `otherServices` node (port 8081).
- [x] Run `php artisan migrate --force` and initialize MariaDB schema.
- [ ] Verify financial data import/restore in Firefly III.
- [ ] Decommission legacy `ezBookKeeping` container and update Caddy `svc:ezbk` route directly to Firefly III.

### CI/CD & Security
- [x] Restrict `tag:ci` SSH access in Tailscale ACLs to non-root `adminUser`.
- [ ] Update GitHub Actions workflows (`ci.yml`, `deploy.yml`) to support two-layer directory execution (`cd layers/1- Infra` then `cd layers/2 - Services`).

---

## Key Learnings & Architectural Decisions

- **Multi-State Decoupling**: Separating VM management from Docker containers eliminates cross-resource locks, speeds up plan cycles, and prevents container recreation when Proxmox metadata changes.
- **Zero-Variable Service Layer**: Layer 2 uses `data.terraform_remote_state` to dynamically discover IP addresses and SSH keys from Layer 1, eliminating variable duplication across workspaces.
- **Least Privilege SSH Access**: Restricting CI runners (`tag:ci`) to non-root users prevents potential repository compromise from resulting in full hypervisor takeover.
