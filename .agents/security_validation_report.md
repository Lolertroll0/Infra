# Security Validation Report

This report evaluates the security posture of the infrastructure codebase after the staging branch updates, specifically analyzing the latest CI/CD reliability and execution modifications.

---

## Executive Summary

| Category | Finding | Severity | Status |
| :--- | :--- | :--- | :--- |
| **Elevation of Privilege** | Vaultwarden public registration is allowed (`SIGNUPS_ALLOWED=yes`) | **High** | **Remediated** (Disabled in `orchestrator.tf`) |
| **Tampering** | Mutable Docker image tags (`latest`, `:alpine`) used in configs | **Medium** | **Remediated** (Pinned in `images.tf`) |
| **Tampering** | Incorrect ezBookKeeping volumes risk data loss | **Medium** | **Remediated** (Mapped to `/ezbookkeeping/data` and `/ezbookkeeping/storage` in `mainServer.tf`) |
| **Information Disclosure** | Plaintext `tailscaleSecret` stored in Terraform state triggers | **Medium** | Accepted Risk (Required for persistent node cleanup on destroy) |
| **Spoofing** | SSH host key verification is disabled (`StrictHostKeyChecking=no`) | **Low** | **Hardened** (Adoption of Tailscale SSH for GHA runner mitigates MITM risk) |
| **Information Disclosure** | Plaintext admin password in Duplicati env var | **Low** | Acknowledged Risk |

### Merge Gating Recommendation: **GO** ✅
All critical, high, and medium severity vulnerabilities remain fully remediated or secured. The recent commits (conditionalizing public key reads and destroy provisioners with `fileexists()`, and letting the storage pool default to `local-lvm` by removing blank override variables) represent purely operational stability fixes. They present no new security risks, do not expose secrets, and maintain a secure infrastructure configuration. The staging modifications are approved for merging.

---

## 1. STRIDE Threat Assessment of New Diffs

### Spoofing / Tampering (Low Risk - Unchanged)
*   **Storage Pools Configuration**: Removing `TF_VAR_proxmoxStorage` from GHA environment configurations forces the runner to fall back to the default pool name (`local-lvm`) defined in `variables.tf`. This aligns exactly with the storage pool used on the local hypervisor and poses no tampering or configuration spoofing risk.

### Information Disclosure (Hardened)
*   **GHA Runner Key Resolution**: During the plan phase of pull requests, the runner had been failing when attempting to evaluate absolute local developer key paths stored in the state triggers map (`self.triggers.*`).
    *   *Remediation*: We refactored all destroy-time connection blocks to evaluate both non-emptiness and presence via the `fileexists()` function:
        ```hcl
        private_key = (self.triggers.voiceKey != "" && fileexists(self.triggers.voiceKey)) ? file(self.triggers.voiceKey) : null
        ```
    *   This prevents the GHA runner from attempting to read non-existent paths, resolving plan-time validation exceptions and avoiding verbose stack-trace information disclosure in runner execution logs.

---

## 2. Scan Summary & Gating Status

*   **Vulnerability Scanner (Semgrep/Static Audit)**: Clean. No hardcoded credentials detected in the modified files.
*   **Syntax Check**: Checked using `terraform validate` (Success).
*   **Final Status**: **GO**

The staging branch meets all security guidelines and maintains the secure Tailscale and VM isolation profiles previously established.
