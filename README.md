# Infrastructure-as-Code: Distributed Home Lab

This repository contains the Terraform configuration for a professional-grade, distributed home infrastructure. It manages resources across physical Proxmox virtual machines, dedicated x86 nodes, and remote Docker hosts, all interconnected via a **Zero Trust** Tailscale mesh network.

---

## 🚀 Project Overview & Current Architecture

The project is structured around a **Multi-State Layered Architecture** managed via **HCP Terraform (Terraform Cloud)**:

- **Layer 1 (`layers/1- Infra`)**: Manages physical & virtual host infrastructure (Proxmox VMs, Cloud-Init, static networking, Tailscale mesh ACL policies, host systemd daemons, and OS provisioning).
- **Layer 2 (`layers/2 - Services`)**: Manages application runtime containers (Caddy, Vaultwarden, Uptime Kuma, Firefly III, ezBookKeeping, Duplicati, Open WebUI) using keyless SSH Docker providers dynamically bound to Layer 1 state outputs.

---

### 🌐 Node Inventory & Responsibilities

```text
                                  ┌────────────────────────────────────────────────────────┐
                                  │               Tailscale Mesh Network                   │
                                  │       (Zero Public Ports · MagicDNS · TLS Ingress)     │
                                  └───────────────┬─────────────────┬──────────────────────┘
                                                  │                 │
                        ┌─────────────────────────┴────────┐        │
                        │                                  │        │
                        ▼                                  ▼        ▼
 ┌───────────────────────────────┐ ┌───────────────────────────────┐ ┌───────────────────────────────┐
 │          Main Server          │ │       Orchestrator Node       │ │         Local AI Node       │
 │        (Proxmox VE x86)       │ │     (Dedicated x86 Mini PC)   │ │  (i5-7500T 4C/4T · 14GB RAM)   │
 ├───────────────────────────────┤ ├───────────────────────────────┤ ├───────────────────────────────┤
 │ • HomeAssistantOS (VM)        │ │ • Tailscale Ingress Gateway   │ │ • LM Studio CLI (Daemon)      │
 │ • ezBookKeeping (VM / Ubuntu) │ │ • Caddy (HTTPS Reverse Proxy) │ │   - qwen2.5-7b-instruct (Chat)  │
 │   - Firefly III (Docker :8081)│ │ • Vaultwarden (Docker)        │ │   - nomic-embed-text (Vectors)  │
 │   - MariaDB 11.4 (Docker)     │ │ • Uptime Kuma (Docker)        │ │   - 4-Thread AVX2 Interceptor   │
 │   - Legacy ezBK (Docker :8080)│ │ • Duplicati (Docker Backup)   │ │ • Open WebUI v0.11.1 (Docker) │
 └───────────────────────────────┘ └───────────────────────────────┘ └───────────────────────────────┘
```

---

### 🛠️ Technologies Used
* **Infrastructure as Code:** Terraform (>= 1.15)
* **Virtualization & Containerization:** Proxmox VE (3.0.2-rc07), Docker
* **Networking & Zero Trust:** Tailscale (MagicDNS, ACLs, Virtual Services, Tailscale SSH), Caddy (Reverse Proxy)
* **State Management:** HCP Terraform (Workspaces: `infrastructure-layer` & `services-layer`)
* **CI/CD & Automation:** GitHub Actions, Bash Scripts, Discord Webhooks
* **Local AI & Text Processing:** LM Studio, llama.cpp (AVX2), Open WebUI, Obsidian RAG (Smart Connections)
* **Core Application Stack:** Home Assistant OS, Firefly III, MariaDB, Vaultwarden, Uptime Kuma, Duplicati

---

### 🔒 Virtual Services & Ingress Routing

All applications are exposed securely inside the private Tailnet via Tailscale Virtual Services (`svc:...`) and reverse-proxied through Caddy on the Orchestrator node:

| Service Subdomain | Backend Target | Port / Protocol | Description |
| :--- | :--- | :--- | :--- |
| **`vaultwarden.${tailnet}`** | `orchestrator:8080` | HTTPS (443) | Bitwarden-compatible password vault |
| **`uptime-kuma.${tailnet}`** | `orchestrator:3001` | HTTPS (443) | Infrastructure health & heartbeat monitoring |
| **`homeassistant.${tailnet}`** | `HomeAssistantOS:8123` | HTTPS (443) | Home automation & IoT gateway |
| **`ff3.${tailnet}`** | `ezbookkeeping:8081` | HTTPS (443) | Firefly III personal finance manager |
| **`chat.${tailnet}`** | `voicepipeline:8080` | HTTPS (443) | Open WebUI interface for local LLMs |
| **`lmstudio.${tailnet}`** | `voicepipeline:1234` | HTTPS (443) | OpenAI-compatible API for Obsidian Vaults |

---

### 🧠 Local AI & Obsidian Vault Integration

The `voicepipeline` node is optimized for private, local LLM text processing and note synthesis:
* **Inference Engine**: Native headless **LM Studio (`lms`)** running as a `systemd` service unit.
* **CPU Acceleration**: Custom multi-core execution interceptor (`scripts/setup-lmstudio.sh.tftpl`) overrides single-threaded defaults to utilize **100% of all 4 CPU cores (`--threads 4`)** with AVX2 vectorization, achieving `<0.5s` Time-To-First-Token.
* **Obsidian RAG**: Exposes standard OpenAI API endpoints (`/v1/chat/completions` and `/v1/embeddings`) for **Smart Connections** and **Copilot for Obsidian**, enabling semantic search across markdown notes using `text-embedding-nomic-embed-text-v1.5`.

---

### 🏗️ Directory Layout

```text
Infra/
├── layers/
│   ├── 1- Infra/                    # Infrastructure Layer (HCP: infrastructure-layer)
│   │   ├── main.tf                  # Proxmox VMs & null_resource host provisioning
│   │   ├── providers.tf             # Proxmox & Tailscale providers
│   │   ├── variables.tf             # Hardware & Tailscale credentials
│   │   ├── outputs.tf               # Node IPs, adminUser, SSH key paths exported to HCP State
│   │   ├── locals.tf                # Common base directory patterns
│   │   └── tailscalePolicy.tf       # Tailscale ACLs, Virtual Services, & SSH authorization policy
│   │
│   └── 2 - Services/                # Application Layer (HCP: services-layer)
│       ├── data.tf                  # Dynamic data binding to "infrastructure-layer" HCP state
│       ├── providers.tf             # Docker providers dynamically targeted via remote state outputs
│       ├── images.tf                # All docker_image definitions with pinned versions
│       ├── locals.tf                # Container base/data/config directory paths
│       └── main.tf                  # All docker_container, docker_network, & docker_volume resources
│
├── caddyfile                        # Reverse proxy routing & header forwarding rules
├── scripts/                         # Key rotation, LM Studio bootstrap, & secret injection scripts
│   ├── setup-lmstudio.sh.tftpl      # Multi-core CPU optimizer & model bootstrap template
│   ├── lmstudio.service.tftpl       # Headless LM Studio systemd service unit template
│   ├── setup-tailscale-serve.sh     # Tailscale Serve ingress registration script
│   └── regenerate-key.sh            # OAuth automated key rotation
└── .github/workflows/              # CI/CD deployment pipelines (ci.yml, deploy.yml)
```

---

## 🔒 Security & Zero Trust Architecture

1. **Zero Port Forwarding**: No public router ports are exposed. All administrative access and inter-service routing occur securely over **Tailscale**.
2. **HCP Remote State Output Bindings**: Layer 2 consumes outputs from Layer 1 via `data.terraform_remote_state` in HCP Terraform. Node IPs, SSH key paths, and administrative credentials are passed dynamically without variable duplication across workspaces.
3. **Least Privilege SSH Access**: Tailscale SSH policies restrict CI runners (`tag:ci`) to non-root `adminUser` execution.
4. **State-Protection Secret Injection**: Sensitive database credentials for Firefly III are injected out-of-band via encrypted backup restores (`scripts/ff3-vars.sh`), ensuring plain-text credentials never touch Terraform `.tfstate` files.
5. **Image Tag Pinning**: Every container image in `images.tf` is locked to explicit, immutable release tags to prevent supply chain contamination.

---

## 🤖 CI/CD & Automation

* **Two-Layer Plan-then-Apply**: Workflows execute deterministically across `layers/1- Infra` and `layers/2 - Services` with automated PR plan summaries.
* **Key Rotation**: Tailscale auth keys are rotated periodically via OAuth API scripts (`scripts/regenerate-key.sh`).
* **Discord Integration**: Build and deployment statuses report real-time execution logs to Discord channels.
