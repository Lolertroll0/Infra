# Security Validation Report: Local AI Transition & Open WebUI v0.11.1 Upgrade

This report evaluates the security posture, threat assessment (STRIDE), and static code analysis of the latest updates to the `voicepipeline` Local AI stack, including the Open WebUI `v0.11.1` upgrade, GNU OpenMP (`libgomp1`) host dependency, and UFW firewall rule for container-to-host bridge ingress.

---

## Executive Summary

| Category (STRIDE) | Finding / Assessment Item | Severity | Status / Mitigation |
| :--- | :--- | :--- | :--- |
| **Tampering** | Docker image version pinning for Open WebUI | **Medium** | **Secured**: Upgraded and pinned to latest stable release (`ghcr.io/open-webui/open-webui:v0.11.1`) in `images.tf` |
| **Spoofing / Access Control** | Host firewalling for Docker bridge (`1234/tcp`) | **Low** | **Secured**: UFW allows `1234/tcp` for Docker bridge gateway (`host.docker.internal`). Outer ingress bounded strictly by Tailscale ACLs (`tag:consumer` & `tag:orchestrator`) |
| **Elevation of Privilege** | GNU OpenMP library installation (`libgomp1`) | **Low** | **Hardened**: Installed official Ubuntu system package (`libgomp1`) for multi-threaded CPU matrix operations in `llama-server`. Added to `main.tf` provisioner |
| **Information Disclosure** | Secret leakage in Terraform files or environment variables | **Low** | **Secured**: Zero credentials, tokens, or private keys introduced. Dummy key `OPENAI_API_KEY=lm-studio` used for client spec compliance |
| **Denial of Service** | Daemon process management & memory headroom | **Low** | **Secured**: `lmstudio.service` configured with `Type=oneshot` and `RemainAfterExit=yes`. Qwen 2.5 7B (`qwen2.5-7b-instruct`) consumes 4.36 GiB RAM, leaving ~7.5 GiB free headroom |

### Merge Gating Recommendation: **GO** ✅
The codebase strictly complies with `.agents/AGENTS.md`, enforces pinned container releases, implements least-privilege host daemons, and contains zero hardcoded credentials.

---

## 1. Prior History Check & Historical Context

Building upon the previous security assessments:
- **Vaultwarden Public Signups**: Signups remain disabled (`SIGNUPS_ALLOWED=false`).
- **Image Pinning Standard**: All application images in `layers/2 - Services/images.tf` remain pinned (`open_webui:v0.11.1`, `caddy:2.7.6-alpine`, `vaultwarden:1.37.1`, `ezbookkeeping:1.5`, `fireflyiii:version-6.6`, `mariadb:11.4`).
- **Tailscale SSH Privileges**: Admin and CI runner access remain scoped strictly to non-root `adminUser`.

---

## 2. STRIDE Threat Assessment

### 🛡️ Spoofing (Identity & Network Access)
* **Firewall Scoping**: `sudo ufw allow 1234/tcp` enables inter-interface communication from Docker container bridge `172.17.0.1` (`host.docker.internal`) to the LM Studio daemon listening on port `1234`. External network ingress remains blocked by router NAT and bounded strictly by Tailscale mesh policy (`tag:consumer` and `tag:orchestrator`).

### 🔒 Tampering (Configuration & Image Integrity)
* **Pinned Release**: Upgraded `docker_image.open_webui` to release tag `ghcr.io/open-webui/open-webui:v0.11.1`, avoiding unpinned tags like `:latest` or `:main`.
* **System Package Provenance**: `libgomp1` is installed via standard Ubuntu apt package repositories (`libgomp1_16-20260322-1ubuntu1_amd64.deb`), ensuring cryptographic hash verification by `apt`.

### 📜 Repudiation (Logging & Auditability)
* **Daemon Audit Logs**: `lmstudio.service` logs startup, model loading (`qwen2.5-7b-instruct`), and execution events to systemd journal (`journalctl -u lmstudio.service`).

### 🔑 Information Disclosure (Secret Handling)
* **Zero Credential Storage**: No secrets or API keys are written to repository files or environment variables, adhering strictly to `.agents/AGENTS.md`. `OPENAI_API_KEY=lm-studio` is used solely as a dummy header.

### ⚡ Denial of Service (Memory & Resource Contention)
* **RAM Allocation Balance**: On the 14 GB `voicepipeline` host, `qwen2.5-7b-instruct` (Q4_K_M) consumes 4.36 GiB RAM. Total system memory usage sits at ~5.1 GiB, preserving >7 GiB of available RAM for OS cache, Open WebUI, and context expansion.

### 👤 Elevation of Privilege
* **Unprivileged Daemon**: LM Studio systemd service unit runs explicitly as `User=${var.adminUser}` (`lolertroll`).

---

## 3. Deep Scanning & Static Analysis Results

* **Secret Pattern Scan**: **PASS** (Zero tokens, secrets, or SSH keys detected in modified files).
* **Terraform Validation**:
  - `layers/1- Infra`: **VALID** (`terraform validate` passed).
  - `layers/2 - Services`: **VALID** (`terraform validate` passed).
* **Terraform Format Check**: **PASS** (`terraform fmt -check -recursive` returned code 0).
* **Final Gating Decision**: **GO** ✅
