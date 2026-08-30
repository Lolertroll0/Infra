# Security Validation Report: Local AI Transition (LM Studio & Open WebUI)

This report evaluates the security posture and architectural risk profile of the latest diffs transitioning the `voicePipeline` node to a dedicated Local AI / LLM inference server.

---

## Executive Summary

| Category (STRIDE) | Finding / Assessment Item | Severity | Status / Mitigation |
| :--- | :--- | :--- | :--- |
| **Tampering** | Docker image mutability for new WebUI container | **Medium** | **Remediated**: Pinned to stable release (`ghcr.io/open-webui/open-webui:v0.5.20`) in `images.tf` |
| **Elevation of Privilege** | `lmstudio.service` daemon execution privileges | **Low** | **Secured**: Service unit runs strictly under non-root `User=${adminUser}` |
| **Information Disclosure** | Secret leakage in Terraform files / environment variables | **Low** | **Secured**: `OPENAI_API_KEY=lm-studio` uses a dummy placeholder; no real credentials touch code or state |
| **Information Disclosure** | Open WebUI authentication bypass (`WEBUI_AUTH=false`) | **Low** | **Accepted Risk**: Protected inside private Zero-Trust Tailnet; can be toggled to `true` if multi-user isolation is needed |
| **Spoofing / Access Control** | Tailscale ACL ingress boundaries for ports `1234` & `8080` | **Low** | **Secured**: Direct access restricted to `tag:consumer` and `tag:orchestrator`; legacy ports `10200`, `10300`, `11434` removed |
| **Denial of Service** | OOM / Resource exhaustion during heavy inference | **Low** | **Hardened**: `lmstudio.service` includes `Restart=always` and `RestartSec=5` for automatic recovery |

### Merge Gating Recommendation: **GO** ✅
The staging diffs strictly adhere to the project's Zero-Trust security model, introduce zero plain-text secrets, enforce non-root daemon execution, and reduce the node's attack surface by eliminating legacy open ports.

---

## 1. Prior History Check & Historical Context

Building on the previous assessment:
- **Vaultwarden Public Signups**: Remains disabled (`SIGNUPS_ALLOWED=false`).
- **Mutable Docker Tags**: The previous finding mandating image tag pinning was applied proactively to `open-webui` (`ghcr.io/open-webui/open-webui:v0.5.20`).
- **Tailscale Secret in Triggers**: Remains accepted risk for automated cleanup.
- **Tailscale SSH Least Privilege**: Enforced; runner and administrative access remain restricted to non-root `adminUser`.

---

## 2. STRIDE Threat Assessment of New Diffs

### 🛡️ Spoofing (Identity & Network Access)
* **Tailscale Mesh Isolation**: The AI node has zero public router port forwardings. Direct TCP communication on port `1234` is restricted to authorized `tag:consumer` devices (client workstations running Obsidian) and `tag:orchestrator`.
* **Zero-Trust Ingress**: Web access to Open WebUI (`chat.${tailnet}`) and LM Studio (`lmstudio.${tailnet}`) routes through Caddy with TLS termination handled by Tailscale Serve (`svc:chat:443`, `svc:lmstudio:443`), preventing MITM attacks.

### 🔒 Tampering (Configuration & Image Integrity)
* **Image Tag Pinning**: Instead of using mutable tags like `:main` or `:latest`, `docker_image.open_webui` is pinned to `ghcr.io/open-webui/open-webui:v0.5.20` in `layers/2 - Services/images.tf` to prevent supply chain poisoning.
* **Modular Template Hashing**: The systemd service file `scripts/lmstudio.service.tftpl` is tracked via `service_hash = md5(...)` in Terraform triggers. Any unauthorized modification or configuration drift triggers automated re-deployment.
* **Volume Mount Isolation**: Persistent data is mounted strictly under `/home/${var.adminUser}/data/open-webui` and `/home/${var.adminUser}/data/lmstudio` with standard user filesystem permissions.

### 📜 Repudiation (Logging & Auditability)
* **Daemon Audit Logs**: Because LM Studio runs as a native systemd unit, all inference errors, startup sequences, and crash logs are tracked in systemd's journal (`journalctl -u lmstudio.service`).
* **Caddy Reverse Proxy Logging**: All HTTP requests to `chat.${tailnet}` and `lmstudio.${tailnet}` are logged at the reverse proxy layer.

### 🔑 Information Disclosure (Secret Handling & Auth)
* **Dummy API Keys**: In strict compliance with `.agents/AGENTS.md`, `OPENAI_API_KEY=lm-studio` is used solely as a dummy header to satisfy OpenAI client specs without storing actual credentials in Terraform.
* **Authentication Profile**: `WEBUI_AUTH=false` allows seamless access for authorized Tailnet users. If sensitive notes are uploaded and you wish to isolate chats between multiple users on your Tailnet, `WEBUI_AUTH` can be toggled to `true`.

### ⚡ Denial of Service (Resource Contention)
* **Daemon Lifecycle**: Running `lms` natively avoids Docker memory overhead and GPU bridge latency. If an out-of-memory (OOM) event occurs under heavy batch context, `systemd` recovers the process automatically (`Restart=always`).
* **Removal of Competing Daemons**: Decommissioning Whisper, Piper, and Ollama frees up all RAM/VRAM exclusively for LM Studio.

### 👤 Elevation of Privilege (Least Privilege Principle)
* **Non-Root Execution**: `lmstudio.service` executes explicitly under `User=${var.adminUser}`, preventing container or process escape to root.
* **Docker Isolation**: Open WebUI runs in an unprivileged container, communicating with the host daemon solely across the internal Docker bridge gateway (`host.docker.internal`).

---

## 3. Deep Scanning & Static Analysis Results

* **Secret Pattern Scan**: **PASS** (Zero credentials, private keys, or tokens detected in modified files).
* **Terraform Validation**:
  - `layers/1- Infra`: **VALID** (`terraform validate` passed).
  - `layers/2 - Services`: **VALID** (`terraform validate` passed).
* **Formatting Check**: **PASS** (`terraform fmt -check -recursive` returned code 0).
* **Final Pre-Merge Status**: **GO** ✅

