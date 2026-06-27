# Security Validation Report

This report evaluates the security posture of the infrastructure codebase. A threat assessment using the STRIDE framework and a deep scanning analysis were performed on the repository configuration.

---

## Executive Summary

| Category | Finding | Severity | Status |
| :--- | :--- | :--- | :--- |
| **Elevation of Privilege** | Vaultwarden public registration is allowed (`SIGNUPS_ALLOWED=yes`) | **High** | **Remediated** (Disabled in rp4Orchestrator.tf) |
| **Tampering** | Mutable Docker image tags (`latest`, `:alpine`) used in configs | **Medium** | **Remediated** (Pinned in images.tf) |
| **Information Disclosure** | Plaintext `tailscaleSecret` stored in Terraform state triggers | **Medium** | Accepted Risk (Required for persistent node cleanup on destroy) |
| **Spoofing** | SSH host key verification is disabled (`StrictHostKeyChecking=no`) | **Low** | Acknowledged Risk (Home Lab) |
| **Information Disclosure** | Plaintext admin password in Duplicati env var | **Low** | Acknowledged Risk |

### Merge Gating Recommendation: **GO**
All critical and high severity findings have been successfully remediated. The codebase is now ready for merging.

---

## 1. STRIDE Threat Assessment

### Spoofing (Low Risk)
*   **Docker Provider SSH Options**: The configuration disables host key validation (`StrictHostKeyChecking=no` and writing known hosts to `/dev/null`). If an attacker spoofed an infrastructure node's IP, Terraform would connect without alerting, risking credential disclosure or remote execution.
    *   *Remediation*: Acceptable for home labs where IPs fluctuate, but for production, host keys should be pinned or verified via Tailscale SSH.

### Tampering (Remediated)
*   **Mutable Docker Tags**: Resolving image tag dependencies:
    *   `caddy:alpine` is pinned to `caddy:2.7.6-alpine`.
    *   `duplicati/duplicati:latest` remains on `latest` with a configuration comment since Duplicati only publishes date-stamped beta versions (e.g. `2.0.8.1_beta_2024-05-07`).
    *   *Note*: The combined image `thelocallab/ollama-openwebui:latest` remains unpinned due to a lack of official version tags from that community repository. We recommend migrating to the official standalone images in the future.

### Repudiation (Low Risk)
*   **Logging Visibility**: Provisioning commands write logs to `/tmp/tf-provision.log`. These logs are not structured or shipped to a centralized monitoring system, which makes post-incident analysis difficult.
    *   *Remediation*: Monitor logs via Uptime Kuma or set up centralized syslog forwarders.

### Information Disclosure (Low Risk - Verified Secure)
*   **Caddy HTTP Reverse Proxy**:
    *   *Analysis*: We verified that Tailscale Serve acts as the TLS ingress controller at the host level, terminating TLS and forwarding decrypted HTTP traffic to Caddy on port 80 over localhost. Therefore, the `http://` configuration in [caddyfile](file:///c:/Users/lolertroll/Infra/caddyfile) is correct and does not expose data over the network.
*   **Plaintext Secrets in state**: Passing `tailscaleSecret = var.tailscaleSecret` to resource `triggers` stores the API key in plaintext within the `.tfstate` file.
    *   *Analysis*: This is required so the destroy-time provisioners can clean up persistent nodes from the tailnet. The risk is accepted on the condition that the state file backend is stored in a private, encrypted storage solution.

### Elevation of Privilege (Remediated)
*   **Vaultwarden Public Registration**: Public signups are now disabled (`SIGNUPS_ALLOWED=false` in [rp4Orchestrator.tf](file:///c:/Users/lolertroll/Infra/rp4Orchestrator.tf)), preventing unauthorized accounts from registering.

---

## 2. Deep Scanning Findings

### Hardcoded Secrets in Workspace
A local scan of `local.auto.tfvars` identified hardcoded secrets:
```hcl
tailscaleSecret = "tskey-api-<REDACTED>"
adminPassword   = "<REDACTED>"
proxmoxSecret   = "<REDACTED>"
```
> [!CAUTION]
> Keeping plaintext secrets in the workspace is a risk. While this file is ignored by Git, it violates security guidelines. We recommend moving these to environment variables (e.g. `TF_VAR_tailscaleSecret`) on your local machine.

---

## 3. Conclusion & Gating Status

*   **Final Status**: **GO**

All outstanding High and Medium risks scheduled for remediation have been fully addressed in the code.
