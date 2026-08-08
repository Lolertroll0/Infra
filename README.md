# Infrastructure-as-Code: Distributed Home Lab

This repository contains the Terraform configuration for a professional-grade, distributed home infrastructure. It manages resources across Proxmox virtual machines and remote Docker hosts, all interconnected via a **Zero Trust** Tailscale mesh network.

---

## 🚀 Project Overview & Current Architecture

The project is structured around a **Multi-State Layered Architecture** managed via **HCP Terraform (Terraform Cloud)**:

- **Layer 1 (`layers/1- Infra`)**: Manages physical & virtual host infrastructure (Proxmox VMs, Cloud-Init, static networking, Tailscale mesh ACL policies, and initial node setup).
- **Layer 2 (`layers/2 - Services`)**: Manages application runtime containers (Caddy, Vaultwarden, Uptime Kuma, Firefly III, ezBookKeeping, Duplicati, Ollama, Whisper, Piper) using keyless SSH Docker providers.

---

### 🛠️ Technologies Used
* **Infrastructure as Code:** Terraform (>= 1.15)
* **Virtualization & Containerization:** Proxmox VE (3.0.2-rc07), Docker
* **Networking & Zero Trust:** Tailscale (MagicDNS, ACLs, Tailscale SSH), Caddy (Reverse Proxy)
* **State Management:** HCP Terraform (Workspaces: `infrastructure-layer` & `services-layer`)
* **CI/CD & Automation:** GitHub Actions, Bash Scripts
* **Core Stack:** Home Assistant OS, Firefly III, MariaDB, Vaultwarden, Uptime Kuma, Duplicati, Ollama, Whisper, Piper, ezBookKeeping

---

### 🏗️ Directory Layout

```text
Infra/
├── layers/
│   ├── 1- Infra/                    # Infrastructure Layer
│   │   ├── main.tf                  # Proxmox VMs & null_resource host provisioning
│   │   ├── providers.tf             # Proxmox & Tailscale providers
│   │   ├── variables.tf             # Hardware & Tailscale credentials
│   │   ├── outputs.tf               # Node IPs, adminUser, SSH key paths exported to HCP State
│   │   ├── locals.tf                # Common base directory patterns
│   │   └── tailscalePolicy.tf       # Tailscale ACLs & SSH authorization policy
│   │
│   └── 2 - Services/                # Application Layer
│       ├── data.tf                  # Dynamic data binding to "infrastructure-layer" HCP state
│       ├── providers.tf             # Docker providers dynamically targeted via remote state outputs
│       ├── images.tf                # All docker_image definitions with pinned versions
│       ├── locals.tf                # Container base/data/config directory paths
│       └── main.tf                  # All docker_container, docker_network, & docker_volume resources
│
├── caddyfile                        # Reverse proxy routing rules
├── scripts/                         # Key rotation & automated secret injection scripts
└── .github/workflows/              # CI/CD deployment pipelines
```

---

## 🔒 Security & Zero Trust Architecture

1. **Zero Port Forwarding**: No public router ports are exposed. All administrative access and inter-service routing occur securely over **Tailscale**.
2. **HCP Remote State Output Bindings**: Layer 2 consumes outputs from Layer 1 via `data.terraform_remote_state` in HCP Terraform. Node IPs, SSH key paths, and administrative credentials are passed dynamically without variable duplication across workspaces.
3. **Least Privilege SSH Access**: Tailscale SSH policies restrict CI runners (`tag:ci`) to non-root `adminUser` execution.
4. **State-Protection Secret Injection**: Sensitive database credentials for Firefly III are injected out-of-band via encrypted backup restores (`scripts/ff3-vars.sh`), ensuring plain-text credentials never touch Terraform `.tfstate` files.

---

## 🤖 CI/CD & Automation

* **Plan-then-Apply**: Workflows generate deterministic plan files (`tfplan`) before applying to guarantee execution safety.
* **Key Rotation**: Tailscale auth keys are rotated periodically via OAuth API scripts (`scripts/regenerate-key.sh`).
* **Discord Integration**: Build and deployment statuses report real-time execution logs to Discord channels.
