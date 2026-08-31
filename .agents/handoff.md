# Infra Project Handoff

This document summarizes the current state, goals, and next steps for the `Lolertroll0/Infra` repository (branch `main`). It is intended as context for future work by the owner or by an AI/code agent.

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

- **Local AI Node (formerly Voice & AI Pipeline Node)**
  - Dedicated x86 node (Intel Core i5-7500T 4C/4T @ 2.70GHz, 14 GB RAM) for local LLM inference and Obsidian Vault text processing.
  - Runs natively via `systemd`:
    - **LM Studio CLI (`lms`)** listening on port `1234` for OpenAI-compatible chat completions (`qwen2.5-7b-instruct`) and vector embeddings (`text-embedding-nomic-embed-text-v1.5`).
    - Automated **multi-core CPU thread optimizer** wrapper (`scripts/setup-lmstudio.sh.tftpl`) forcing all 4 cores with AVX2 vectorization.
  - Runs Docker with:
    - **Open WebUI (v0.11.1)** on port `8080` for browser-based ad-hoc chat, testing, and model management.
  - Decommissioned legacy Whisper, Piper, and Ollama containers to dedicate 100% of node memory/compute to LLM & embedding workloads.

- **Networking & security**
  - All nodes join the same **Tailscale tailnet**; zero router port forwardings.
  - Services are accessed by consumer devices on Tailscale via subdomains:
    - `vaultwarden.${tailnet}`
    - `uptime-kuma.${tailnet}`
    - `homeassistant.${tailnet}`
    - `ff3.${tailnet}`
    - `chat.${tailnet}`
    - `lmstudio.${tailnet}`
  - **Tailscale** on the orchestrator host terminates TLS for the Virtual Services (`svc:vaultwarden`, `svc:uptime-kuma`, `svc:homeassistant`, `svc:ezbk`, `svc:ff3`, `svc:chat`, `svc:lmstudio`) and forwards requests to Caddy on local port 80.
  - **Caddy** inspects the Host header and reverse-proxies matching hosts to local containers or remote nodes.
  - **Tailscale ACLs** and tags define strict network isolation:
    - Port `1234` (LM Studio direct API): Accessible strictly by `tag:consumer` (Obsidian client workstations) and `tag:orchestrator`.
    - Port `8080` (Open WebUI): Accessible via reverse proxy over `chat.${tailnet}`.
    - CI runner (`tag:ci`) is restricted to non-root `adminUser` SSH access.

---

### Layered Multi-State Architecture (`layers/`)

The repository is structured into a **Layered Architecture** with **HCP Remote State Sharing**:

```text
layers/
├── 1- Infra/                    # Infrastructure Layer (HCP Workspace: infrastructure-layer)
│   ├── main.tf                  # Proxmox VMs & null_resource host provisioning (Docker, Tailscale, LM Studio)
│   ├── providers.tf             # Proxmox & Tailscale providers
│   ├── variables.tf             # Hardware & Tailscale credentials
│   ├── outputs.tf               # Node IPs, adminUser, SSH key paths exported to HCP State
│   ├── locals.tf                # Common base directory patterns
│   └── tailscalePolicy.tf       # Tailscale ACLs, Virtual Services, & SSH authorization policy
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

- **Open WebUI Upgrade (`v0.11.1`)**: Updated `docker_image.open_webui` from `v0.5.20` to `v0.11.1` in Layer 2 `images.tf` with pinned release tags.
- **Docker Host Gateway UFW Ingress Fix**: Diagnosed and resolved 500 Connection Timeout Errors between Open WebUI container (`172.17.0.1`) and host LM Studio daemon (`1234/tcp`). Added `ufw allow 1234/tcp` to `null_resource.setup_voicePipelineEnvironment` in Layer 1 `main.tf`.
- **Multi-Core CPU Thread Wrapper Codification**: Discovered LM Studio CLI defaulted to single-threaded inference (`--threads 1`) on Linux. Created `scripts/setup-lmstudio.sh.tftpl` to dynamically intercept `llama-server` execution, set `OMP_NUM_THREADS=$(nproc)`, and override `--threads $(nproc)`, cutting Time-To-First-Token (TTFT) to **0.48s** and reducing generation time by **2.5x**.
- **Context Length Expansion (`n_ctx: 8192`)**: Configured default context length to `8192` tokens during model bootstrap in `setup-lmstudio.sh.tftpl`, preventing Open WebUI multi-turn context overflow exceptions (`HTTP 400 exceed_context_size_error`).
- **Open WebUI Prompt Latency Root Cause**: Identified that Open WebUI v0.11.1 defaults to injecting extensive JSON tool schemas into every chat prompt, causing 15-20s prompt evaluation delays on CPU. Documented best practice of disabling unused tools/web search in chat settings for sub-second generation.
- **Model Provisioning & Loading**: Pre-loaded `qwen2.5-7b-instruct` (4.68 GB Q4_K_M) and `text-embedding-nomic-embed-text-v1.5` on `voicepipeline` with total memory footprint under 5.5 GiB, leaving >9 GiB available RAM.
- **Obsidian Vault Full-Stack Integration Guide**: Documented complete setup for **Smart Connections** (vault-wide RAG & embeddings) and **Copilot for Obsidian** (chat sidebar & inline text generation) connecting across Tailscale Zero-Trust ingress.
- **Pre-Merge Security Validation (`/sec-validation`)**: Completed STRIDE threat modeling, static code analysis, and secret scanning with a formal **GO** gating decision.

---

## TODOs / Next Steps

### Core Infrastructure & Cleanup
- [x] Refactor monolith into `layers/1- Infra/` and `layers/2 - Services/`.
- [x] Configure HCP Remote State data source bindings in Layer 2.
- [x] Remove legacy root-level `.tf` files after confirming clean plans.
- [ ] Set up HCP Terraform Run Triggers so an apply in `infrastructure-layer` automatically triggers a plan in `services-layer`.

### Data Migration & Application Stack
- [x] Deploy Firefly III container stack on `otherServices` node (port 8081).
- [x] Run `php artisan migrate --force` and initialize MariaDB schema.
- [x] Fix Firefly III frontend HTTPS asset scheme forcing (`APP_URL=https://...`, `TRUSTED_PROXIES=*`, `FORCE_SCHEME_HTTPS=true`, Caddy `header_up X-Forwarded-Proto https`).
- [ ] Verify financial data import/restore in Firefly III.
- [ ] Decommission legacy `ezBookKeeping` container and update Caddy `svc:ezbk` route directly to Firefly III.
- [x] Decommission Piper, Whisper, and Ollama and deploy Local AI stack (LM Studio + Open WebUI).
- [x] Codify LM Studio multi-core CPU optimization, UFW firewalling, and 8k context in Layer 1.
- [ ] (Optional) Download lightweight secondary model (`qwen2.5-3b-instruct`) for ultra-fast inline note editing (>15 tokens/sec).

### CI/CD, Backups, & Security
- [x] Restrict `tag:ci` SSH access in Tailscale ACLs to non-root `adminUser`.
- [x] Update GitHub Actions workflows (`ci.yml`, `deploy.yml`) to support two-layer directory execution.
- [x] Fix relative log redirect pathing for sequential CI PR comment outputs.
- [ ] Design and implement comprehensive backup/recovery strategy for Docker volumes (Duplicati) and Proxmox VMs.

---

## Key Learnings & Architectural Decisions

- **Multi-State Decoupling**: Separating VM management from Docker containers eliminates cross-resource locks, speeds up plan cycles, and prevents container recreation when Proxmox metadata changes.
- **Zero-Variable Service Layer**: Layer 2 uses `data.terraform_remote_state` to dynamically discover IP addresses and SSH keys from Layer 1, eliminating variable duplication across workspaces.
- **Least Privilege SSH Access**: Restricting CI runners (`tag:ci`) to non-root users prevents potential repository compromise from resulting in full hypervisor takeover.
- **Keyless SSH via Tailscale**: By passing empty strings as SSH keys in CI, the Terraform Docker provider falls back to using Tailscale's cryptographic machine identity for authorization, keeping zero static keys in GitHub Secrets.
- **Native HCL Imports**: Using the Terraform 1.5+ `import {}` block natively handles state import logic (e.g. for `tailscale_acl`) inside CI workflows, preventing the need for ad-hoc CLI commands handling remote state authentication.
- **Reverse Proxy Scheme Forwarding (`X-Forwarded-Proto`)**: When Caddy sits behind a TLS-terminating ingress gateway (Tailscale Serve) and listens locally on HTTP port 80, Caddy's default `reverse_proxy` behavior sets `X-Forwarded-Proto: {http.request.scheme}` (evaluating to `http`). For HTTPS-sensitive web applications like Firefly III (Laravel), explicitly passing `header_up X-Forwarded-Proto https` in `caddyfile` guarantees that downstream applications evaluate `$request->secure()` as true and output matching HTTPS base URIs.
- **LM Studio Systemd Daemon Execution Mode**: Configured `lmstudio.service` with `Type=oneshot` and `RemainAfterExit=yes` because `lms server start` launches the server backend as a background daemon and exits with status 0. Added `ExecStop=/usr/local/bin/lms server stop` and added `/home/${var.adminUser}/.lmstudio/bin` to service `PATH`.
- **LM Studio CPU Backend Dependency (`libgomp1`)**: Headless `llama-server` binaries packaged with LM Studio require GNU OpenMP (`libgomp.so.1`) for multi-threaded CPU matrix operations. Fixed exit code `127` during `lms load` by installing `libgomp1` on the host OS and adding it to `null_resource.setup_voicePipelineEnvironment`.
- **Docker Host Gateway Firewalling (UFW Port 1234)**: When containerized frontends (Open WebUI) address host daemons (LM Studio) via `host.docker.internal` (`172.17.0.1:1234`), UFW on the host OS blocks inter-interface bridge traffic by default. Allowed `1234/tcp` in UFW (`sudo ufw allow 1234/tcp`), resolving 500 Connection Timeout Errors and unlocking model population in Open WebUI.
- **LM Studio Multi-Core CPU Thread Wrapper (`llama-server`)**: On headless Linux, LM Studio CLI defaults to single-threaded execution (`--threads 1`) when multiple parallel slots are configured, leaving other CPU cores idle. Automated an interception wrapper (`scripts/setup-lmstudio.sh.tftpl`) in `null_resource.setup_lmstudioService` that dynamically sets `export OMP_NUM_THREADS=$(nproc)` and overrides `--threads $(nproc)`, unlocking 100% CPU utilization across all cores and cutting latency by more than 2.5x.
- **Context Length Expansion for WebUI & RAG (`n_ctx: 8192`)**: Set LM Studio default context to `8192` tokens during model loading in `setup-lmstudio.sh.tftpl`, accommodating large multi-turn chat threads without triggering Open WebUI `400 Bad Request` context overflow errors.
- **Caddy Upstream Hostname Exact Match**: Fixed hostname typo in `caddyfile` from `voice-pipeline` to `voicepipeline` (matching the exact Tailscale MagicDNS node hostname), resolving 502 Bad Gateway proxy errors.
- **Tailscale Virtual Services (`svc:...`) Control Plane Propagation**: New Virtual Services added to `tailscalePolicy.tf` (`autoApprovers.services`) must be applied via `terraform apply` in Layer 1 (`Deploy Infra` workflow in GitHub Actions) to sync with `api.tailscale.com`. Once approved by Tailscale Control Plane and registered via `sudo /tmp/setup-tailscale-serve.sh` on Orchestrator, MagicDNS allocates virtual IPs (`100.x.y.z`) and routes TLS-terminated HTTPS traffic cleanly to Caddy.
