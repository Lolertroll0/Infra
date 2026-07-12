# Infra Project Handoff

This document summarizes the current state, goals, and next steps for the `Lolertroll0/Infra` repository (branch `stage`). It is intended as context for future work by the owner or by an AI/code agent.

---

## Project Goal

Build a professional-grade, **distributed home lab** managed entirely via **Infrastructure as Code (Terraform)**, focusing on:

- Practicing DevOps skills: Terraform, multi-provider setups (Proxmox, Docker, Tailscale), CI/CD with GitHub Actions.
- Applying **Zero Trust** and secure networking using **Tailscale** (MagicDNS, ACLs, Tailscale SSH) and **Caddy** as an HTTPS reverse proxy.
- Designing an architecture that spans **physical x86 (Proxmox)** and dedicated x86 Mini PC nodes, with clear responsibility boundaries.
- Implementing **SRE-style practices**: reproducible deployments, key rotation, controlled destroy behavior (e.g., Tailscale logout), and eventually backup/recovery workflows.
- Using this home lab as a learning vehicle for moving from QA to DevOps/SRE engineering.

---

## Current Architecture & State

### High-level topology

- **Main Server (Proxmox / x86)**
  - Proxmox node hosting:
    - `HomeAssistantOS` VM (appliance-style Home Assistant OS).
    - `ezBookKeeping` VM for running Dockerized ezBookKeeping.
  - Terraform manages VMs via the Proxmox provider and uses cloud-init for the ezBookKeeping VM.

- **Orchestrator Node (Mini PC / x86_64)**
  - Acts as the **HTTP(S) entry point** into the tailnet services.
  - Runs Docker with:
    - **Caddy** as a reverse proxy routing services via subdomain host headers.
    - **Uptime Kuma** for monitoring/heartbeats.
    - **Vaultwarden** for password management.
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
  - **Tailscale** on the orchestrator host terminates TLS for the Virtual Services (`svc:vaultwarden`, `svc:uptime-kuma`, `svc:homeassistant`) and forwards requests to Caddy on local port 80.
  - **Caddy** inspects the Host header and reverse-proxies matching hosts to:
    - Local containers (same host, via Docker network).
    - Home Assistant (remote service on the main server via its tailnet URL).
  - **Tailscale ACLs** and tags define which nodes and tags can talk to which ports, plus Tailscale SSH access rules. The voice pipeline is isolated so only Home Assistant (`tag:mainServer`) can access Whisper, Piper, and Ollama.


- **Terraform layout**
  - Backend: Terraform Cloud workspace `distributed-homeserver`.
  - Providers: `kreuzwerker/docker` (`~> 4.0`), `Telmate/proxmox` (pinned to `3.0.2-rc07`), `tailscale/tailscale` (`~> 0.28.0`).
  - Key files:
    - `providers.tf`: backend and providers.
    - `variables.tf`: all admin, MagicDNS, SSH, Tailscale, and Proxmox variables.
    - `local.auto.tfvars`: Local variables file containing credentials/tokens, node IPs, and SSH key paths (local only / gitignored).
    - `mainServer.tf`: Proxmox VMs and provisioning for ezBookKeeping.
    - `orchestrator.tf`: orchestrator setup and containers.
    - `voicePipeline.tf`: voice node setup and containers.
    - `images.tf`: all Docker image resources.
    - `locals.tf`: centralized path patterns (`base_dir`, `data_dir`, `config_dir`).
    - `tailscalePolicy.tf`: ACLs and SSH rules.
    - `caddyfile`: Reverse proxy rules utilizing subdomain-based routing.
    - `env.template`: list of required environment variables.

- **CI/CD and automation**
  - GitHub Actions for plan-then-apply workflows and Tailscale key rotation.
  - `scripts/regenerate-key.sh` for rotating Tailscale auth keys via OAuth.
  - Discord notifications for deployment observability via `tsickert/discord-webhook`.

- **Deployment status**
  - All 23 infrastructure resources have been successfully destroyed and redeployed clean from scratch.
  - Tailscale keys for all nodes (`tag:orchestrator`, `tag:mainserver`, `tag:voice`) were regenerated using the Tailscale REST API and stored in `local.auto.tfvars`.
  - Destroy provisioners in [mainServer.tf](file:///C:/Users/lolertroll/Infra/mainServer.tf#L148-L162), [orchestrator.tf](file:///C:/Users/lolertroll/Infra/orchestrator.tf#L40-L54), and [voicePipeline.tf](file:///C:/Users/lolertroll/Infra/voicePipeline.tf#L38-L52) have been refactored to use `jq` for robust device ID lookup (`jq -r '.Self.ID'`) and made resilient with `set +e` and `exit 0` to prevent blocker errors if a node is already logged out.
  - Pushed updated path-based routing definitions in the `Caddyfile` for `/homeassistant`, `/ezbk`, `/ollama`, `/whisper`, and `/piper` utilizing the correct DNS names (`homeassistant.local`, `ezbookkeeping.tailded50c.ts.net`, and `voicepipeline.tailded50c.ts.net`).
  - Active Tailscale connections have been verified for the orchestrator (`homeserver`), `ezbookkeeping-1`, and `voicepipeline`. Offline duplicate devices have been completely purged from the tailnet.
  - Deployed the `duplicati` container on the orchestrator node with port `8200` exposed and read-only bind mounts to the `uptimeKuma` and `vaultwarden` host data directories for secure automated backups.
  - Resolved connection blocking from Home Assistant OS to the Voice Pipeline node by correcting the case mismatch of the `tag:mainServer` tag, renaming it to lowercase `tag:mainserver` across the policy file and key generation scripts.
  - Modified [mainServer.tf](file:///C:/Users/lolertroll/Infra/mainServer.tf) to map the correct persistent volume paths for the `ezBookKeeping` container (`/ezbookkeeping/data`, `/ezbookkeeping/storage`, `/ezbookkeeping/log`, `/ezbookkeeping/conf`), preventing database and file uploads from being lost on container recreation.
  - Enforced target directory permission ownership (`1000:1000`) inside the `setup_ezBookKeeping` VM provisioner to prevent database write permission failures.
  - Restructured the CI/CD pipeline targeting `main` to run `plan` and `apply` sequentially in `deploy.yml`, solving the GitHub Actions cross-workflow artifact download constraint.
  - Hardened CI/CD security by adopting keyless **Tailscale SSH** for runner authentication. Replaced static private key files inside [providers.tf](file:///c:/Users/lolertroll/Infra/providers.tf) with a dynamic `ssh_opts` configuration (allowing both local key files and keyless Tailscale SSH to coexist based on empty key path checks). Removed all 10+ SSH key secrets and agent configuration steps from GitHub Actions workflows.
  - Corrected [orchestrator.tf](file:///c:/Users/lolertroll/Infra/orchestrator.tf) to map the `uptimeKuma` container data path to `/app/data` (previously `/data`), securing persistence of monitoring history and databases across container replacements.
  - Configured `uptimeKuma` with `dns = ["100.100.100.100"]` to allow resolution of private Tailscale MagicDNS (`*.ts.net`) addresses, fixing DNS lookup failures (`ENOTFOUND`).
  - Restored backend access rule `"tag:mainserver:8080"` and added `"group:admin"` to Tailscale SSH permissions in [tailscalePolicy.tf](file:///c:/Users/lolertroll/Infra/tailscalePolicy.tf) to restore Caddy reverse proxy pathways and secure SSH management access.
  - Resolved Tailscale API out-of-sync conflicts by removing the ACL resource from the local state database and re-importing the active console configurations.
  - Migrated Docker providers to connect keylessly over identity-based Tailscale SSH by resolving local developer ACL access on `tag:consumer` and `group:admin`. All docker providers successfully connect via MagicDNS hostnames instead of LAN IPs.
  - Resolved `terraform: command not found` error in CI/CD pipeline by adding a setup step for Terraform in `.github/workflows/ci.yml`.
  - Authorized GHA runner (`tag:ci`) to communicate with infrastructure hosts over the Tailnet by adding network-level access rules to port 22 (SSH) and port 8006 (Proxmox API) in `tailscalePolicy.tf` and applying them locally.
  - Refactored VM definitions and provisioner configurations in `mainServer.tf`, `orchestrator.tf`, and `voicePipeline.tf` to conditionally read SSH private and public key files only when their paths are non-empty. This fixes evaluation-time plan failures (e.g. `read .: is a directory` and missing file crashes) in CI/CD environments.

- **Day 0 Bootstrapping Strategy**
  - **Node IP Table (LAN/Bootstrap Phase)**:
    - Proxmox API & Host SSH: `192.168.1.100` (Gateway: `192.168.1.1`)
    - ezBookKeeping VM: `192.168.1.102` (via Docker `otherServices` provider)
    - HomeAssistantOS VM: `192.168.1.103`
    - Orchestrator (Mini PC): `192.168.1.25`
    - Voice & AI Pipeline Node: `192.168.1.16`
  - **SSH Keys Setup**:
    - Dedicated SSH keypairs created locally at `C:/Users/lolertroll/.ssh/` named `mainServer`, `orchestrator`, `voicePipeline`, `otherServices`, and `homeAssistant` (with matching `.pub` counterparts).
  - **Proxmox Token Credentials**:
    - Uses token ID `terraform@pam!TERRAFORM` under the `pam` realm.
    - VM Template IDs: `103` (HAOS template) and `100` (ezBookKeeping template).
  - **Step-by-step Bootstrapping Protocol**:
    1. Populate real Tailscale auth keys (e.g. `tskey-auth-...`) in `local.auto.tfvars`.
    2. Ensure VM templates `103` and `100` exist on Proxmox, and storage names `haosstorage` and `financialStorage` exist.
    3. Run a targeted Terraform apply on Tailscale resources and Proxmox VM setups.
    4. Retrieve generated auth keys from Terraform state or console.
    5. Manually register and perform `tailscale up --ssh` on the nodes over LAN.
    6. Once nodes are connected to Tailscale, update connections in `local.auto.tfvars` from raw IPs to their MagicDNS hostnames.
    7. Perform a full `terraform apply` to achieve the desired state using secure Tailscale networks.

---

## TODOs / Next Steps

This section lists actionable items to move the project toward a stable, professional-grade state.

### Immediate (Before First Full Deploy)

- [x] **Fix Proxmox Ubuntu Template**: Re-enable `cloud-init` in the base template so that it processes the static IP (`ipconfig0`) configured by Terraform.
- [x] Run targeted Tailscale bootstrap apply for `ezBookKeeping` VM.
- [x] Add `local.auto.tfvars` to `.gitignore` (automatically covered by `*.tfvars` entry).
- [x] Run targeted Tailscale bootstrap apply and register all physical machines on the tailnet.
- [x] Replace `tailscaleOrchestratorAuthKey`, `tailscaleMainAuthKey`, `tailscaleVoiceAuthKey` dummy values in `local.auto.tfvars` with real `tskey-auth-...` values.
- [x] Manually copy SSH public keys to each physical machine's `~/.ssh/authorized_keys` before running `terraform apply`.
- [x] Update `mainServer`, `orchestrator`, `voicePipeline` in `local.auto.tfvars` to Tailscale MagicDNS names once nodes are on the tailnet.
- [ ] Populate the corresponding secrets in the GitHub repository to enable CI/CD pipeline (mirrors `env.template`).
- [x] Update `env.template` and GHA workflows (`ci.yml`, `deploy.yml`) to align with all current variables and `local.auto.tfvars`.
- [x] Verify that `br-vm`, `haosstorage`, and `financialStorage` exist on the Proxmox host before running a full apply.

### Core Terraform & infra hygiene

- [x] Fix Terraform `required_version` constraint in `providers.tf` (`>= 1.15`).
- [x] Introduce `locals.tf` for common path patterns like `/home/${adminUser}/data/...` to avoid repetition.
- [ ] Ensure all required secrets and MagicDNS names are set via GitHub Secrets.
- [ ] Modularize Terraform into per-node modules:
  - `modules/main_server`, `modules/orchestrator`, `modules/voice_pipeline`.
  - Root config becomes wiring + providers + high-level variables.

### Containers and provisioning

- [x] Refactor **ezBookKeeping** provisioning:
  - Replace `docker run` in `null_resource.setup_ezBookKeeping` with proper `docker_image` and `docker_container` resources, managed by the Docker provider.
  - Make the provisioner responsible only for host prep (Docker install, Tailscale, directory creation).
- [x] Ensure all `null_resource` provisioners are **idempotent**:
  - Avoid commands that fail on re-run (e.g., `docker run` when the container already exists).
  - Prefer `mkdir -p`, checks, or move object creation into Terraform-managed resources.
- [x] Relax SSH timeouts a bit (`1m`/`2m` → `3m`–`5m`) to handle slow first-time installs.

### Networking and security

- [x] Correct Caddy volume mapping:
  - Mount the host Caddyfile as a file: `host_path = ".../Caddyfile"` → `container_path = "/etc/caddy/Caddyfile"` instead of mounting a single file as a directory.
- [x] Orchestrator containers (same host as Caddy):
  - Remove host port mappings for Uptime Kuma and Vaultwarden.
  - Expose them only on the internal Docker network and let Caddy reverse-proxy to them.
- [x] Voice node containers:
  - Decide whether to keep host ports (for direct Tailscale access) or introduce a proxy on that node.
  - If accessed only through Caddy on the orchestrator, host ports remain needed on the voice node; if a local proxy is added, containers can be internal-only.
- [ ] Improve SSH security on Docker providers:
  - Replace `StrictHostKeyChecking=no` and `/dev/null` known_hosts with a pinned `known_hosts` file once node host keys are stable.

### Tailscale policy & naming consistency

- [x] Remove duplicated ACL rules in `tailscalePolicy.tf` (duplicate `tag:consumer` → `tag:orchestrator:*` entries).
- [x] Decide whether the voice node should also receive `dns-subdomain-resolve` node attributes.
- [x] Document and enforce a naming convention for:
  - Tailscale node names and tags (`tag:mainserver`, `tag:orchestrator`, `tag:voice`, `tag:consumer`).
  - MagicDNS hostnames now consistently use `mainServer`, `orchestrator`, and `voice` across all files.

### Versioning and updates

- [x] Replace `:latest` tags with explicit version tags (or digests) for services like Vaultwarden and Ollama/OpenWebUI.
- [x] Define a simple update policy:
  - e.g., monthly/quarterly review of upstream image releases.
  - Bump tags intentionally, test apply, then promote.
- [x] Document the rationale:
  - Security-sensitive services are kept reasonably up to date while still having repeatable, testable updates.

### Backups and recovery (SRE focus)

- [ ] Design and implement a backup strategy for:
  - Stateful Docker volumes on orchestrator and voice node.
  - Proxmox VMs (HAOS, ezBookKeeping host).
- [ ] Implement scheduled backups (Proxmox jobs and host-level backup scripts/tools like restic/borg/rsync).
- [ ] Write **recovery runbooks** for at least:
  - Orchestrator node failure (SD card/board dead).
  - Proxmox node failure.
  - Voice node failure.
- [ ] Perform at least one real recovery test (e.g., wipe and rebuild orchestrator from backups + Terraform).

### CI/CD and automation

- [x] Finalize GitHub Actions workflows:
  - Plan-only on PR targeting `main` (posting plan diffs to PR comments).
  - Sequential Plan and Apply on merge (push) to `main`.
- [x] Migrate GitHub Actions runner to Tailscale SSH keyless authentication, simplifying workflow steps.
- [ ] Delete deprecated SSH private/public key secrets from GitHub Repository Secrets settings.
- [x] Wire `scripts/regenerate-key.sh` into a scheduled or on-demand workflow for Tailscale auth key rotation.
- [x] Hook Terraform and rotation workflows into Discord or another notification sink for visibility.

---

## Key Learnings & Architectural Decisions

This section captures key decisions and mental models that future agents should preserve.

- **Zero trust baseline**
  - No router port forwarding; all traffic is over Tailscale.
  - Consumer devices join the tailnet and use subdomain MagicDNS hostnames.

- **Ingress model**
  - Tailscale Virtual Services on the orchestrator node act as the entry point and terminate TLS for `vaultwarden`, `uptime-kuma`, and `homeassistant`.
  - Caddy on the orchestrator receives local plaintext HTTP on port 80 and uses Host headers to route to the backend containers or VM.
  - Caddy trusts the proxy headers using `trusted_proxies static 127.0.0.1`.
  - ezBookKeeping VM bypasses Caddy completely and is accessed directly on its own Tailscale MagicDNS name on port 8080.

  - SSH is handled directly via Tailscale SSH / Tailscale IPs, not via Caddy.

- **Host vs container networking**
  - Orchestrator services (Caddy, Uptime Kuma, Vaultwarden) are intended to talk over an internal Docker network, without host port exposure.
  - Voice node services need host ports open on that node if they are reached from Caddy on another host.

- **Provisioners are for bootstrap, Terraform for steady-state**
  - `null_resource` + `remote-exec` is used to install Docker, install Tailscale, and create directories.
  - Long-lived services should ideally be modeled as Terraform-managed `docker_container` resources rather than being started in shell provisioners.

- **Lifecycle management**
  - Destroy provisioners call `tailscale logout` so nodes are cleanly removed from the tailnet when destroyed.
  - Future recovery protocols should lean on: restore data → rejoin Tailscale → `terraform apply` to reconstruct services.

- **Versioning philosophy**
  - The project aims to balance security updates with reproducibility:
    - Avoid unbounded `latest` tags.
    - Prefer pinned versions plus a regular update cadence for security-sensitive services.

- **Proxmox VM Templating & Booting**
  - The Terraform Proxmox provider (`Telmate/proxmox`) defaults to an `lsi` SCSI controller. Modern Linux templates often require `scsihw = "virtio-scsi-pci"` to avoid dropping into a Dracut emergency shell (`/dev/disk/by-uuid/` not found).
  - Base Ubuntu templates created with the Subiquity installer often leave `cloud-init` disabled after installation. It must be manually re-enabled (removing `/etc/cloud/cloud-init.disabled` if present, enabling systemd units like `cloud-init-main.service`, and running `cloud-init clean --logs`) prior to cloning.
  - **Predictable Interface Naming Conflict**: Ubuntu's default naming (e.g. `ens18`) conflicts with Cloud-Init's expectation of `eth0`. Interface renames fail on modern guest kernels, causing static IP settings to be ignored and falling back to DHCP. Fix this by adding `net.ifnames=0 biosdevname=0` to `GRUB_CMDLINE_LINUX_DEFAULT` in the template's `/etc/default/grub` and running `sudo update-grub`.
  - **Datasource Detection**: Force Cloud-Init to find Proxmox's virtual metadata CD-ROM by adding `datasource_list: [NoCloud, ConfigDrive, None]` to `/etc/cloud/cloud.cfg.d/99_pve.cfg` in the template VM.
  - **Linked Clones vs Full Clones**: Using `full_clone = false` (Linked Clones) reduces the `ezBookKeeping` VM deploy time from ~6 minutes to ~20 seconds by sharing the template base disk, which is highly efficient for development and debugging.
  - **Windows SysWOW64 Redirect on OpenSSH**: The Terraform Docker provider binary (being a 32-bit execution context on some plugins) failed to locate the Windows system `ssh` executable in `C:\Windows\System32\OpenSSH\` because Windows file system redirection redirects `System32` searches to `SysWOW64` (where OpenSSH does not exist). Bypassed this by copying `ssh.exe` to a non-system folder (`C:\Users\lolertroll\ssh.exe`) and prepending it to the `PATH`.
  - **Proxmox USB Device Permissions**: Cloning or creating a VM containing a physical USB passthrough (`usb0`) is strictly restricted to the `root@pam` user by default on Proxmox. API tokens with `Sys.Modify` or `Administrator` privileges will get a `500 only root can set 'usb0' config` error. To bypass, detach the USB device from the template VM (`mainServer`) and let Terraform clone/deploy it successfully.
  - **Automated USB Attachment**: To automate re-attaching the USB device in the CI/CD pipeline, we implemented `null_resource.attach_haos_usb` in [mainServer.tf](file:///C:/Users/lolertroll/Infra/mainServer.tf#L160) which SSHs into the Proxmox host (`192.168.1.100`) as `root` and executes the `qm set` command. This is mapped to `var.homeAssistantUSB` and guarded by a `count` conditional so it is safely skipped when the value is left empty (`""`). In the current run, the physical USB device ID `8087:0a2a` was successfully attached.
  - **USB State Reconciliation & API Drift Issue**: If VM settings (like disk slots or memory) are updated in Terraform while a physical USB is attached, the Proxmox provider will attempt to serialize and send the entire VM state (including `usb0`) to the Proxmox API. Even with `ignore_changes = [usbs]` configured, the provider will still include the cached state value of `usb0` in the PUT request, triggering the `500 only root can set 'usb0' config` permission error.
    - *Resolution workflow*:
      1. Detach the USB from the VM manually via root SSH: `ssh root@<pve-ip> "qm set <vmid> -delete usb0"`.
      2. Temporarily comment out `usbs` from `ignore_changes` in the VM block inside `mainServer.tf`.
      3. Run `terraform apply`. This forces Terraform to refresh, detect that `usb0` is absent from the host, and remove it from the local state.
      4. Uncomment `usbs` in `ignore_changes` to restore the ignore policy.
      5. Re-attach the physical USB device: `ssh root@<pve-ip> "qm set <vmid> -usb0 host=<device-id>"`.
  - **Perpetual Disk-Swapping Drift**: The Telmate/proxmox provider has a known issue where it gets confused about the disk list order (sometimes assigning matching IDs to multiple disks like `ide0` and `scsi0`), causing Terraform to perpetually plan to swap the disk slot configurations on every apply.
    - *Resolution*: Add `disk` (and `efidisk` if applicable) to the VM's `lifecycle { ignore_changes = [...] }` block. Once the VM boot layouts are established, this prevents unnecessary API modifications to disks, which additionally prevents triggering the USB permission error during unrelated runs.

- **Tailscale Serve vs Container Ports**: Host-level Tailscale Serve binds to port 443 of the host to handle TLS termination. Exposing port 443 on the container (like Caddy) creates a port conflict. Resolve this by removing port 443 bindings from the container configuration and letting Tailscale handle it, routing as HTTP to Caddy's exposed port 80.
- **Docker Internal Network Port Forwarding Limitations**: Declaring `internal = true` on a custom Docker network prevents Docker from setting up host port mappings/forwarding rules. To expose container ports on the host's localhost or IP (e.g. for Tailscale Serve target, or cross-node communication), networks must be standard non-isolated bridge networks (`internal = false`). Internal network configuration also blocks outbound internet egress.
- **Caddy Behind TLS Terminating Proxies**: To prevent infinite HTTPS redirect loops behind a TLS-terminating proxy (like Tailscale Serve), Caddy must be instructed to only listen on HTTP (using the `http://` prefix in Caddyfile domain headers, e.g., `http://homeserver.${tailnet}`) rather than attempting to enforce automated HTTPS/redirects.

- **Tailscale Virtual Services & Tag-based Auth Requirements**:
  - Virtual Services (`svc:<name>`) must first be explicitly defined on the Tailscale Admin Console (Services tab) before the daemon's local `tailscale serve --service` configuration can successfully advertise them and clear the `"approval from an admin is required"` block.
  - Devices on the tailnet that are expected to communicate under tag-based policies (such as the Home Assistant VM needing `tag:mainserver` access to Wyoming Voice nodes on `tag:voice`) **must** be authenticated using a pre-authorized, tag-configured auth key rather than a standard user login. User-authenticated nodes do not inherit tags, preventing the matches required by strict ACL policies.
  - **Tailscale ACL Tag Case-Sensitivity**: Tailscale tags are strictly case-sensitive. Device tags must match the casing defined and referenced in the ACL policy exactly. Using all-lowercase tags (e.g. `tag:mainserver`) is recommended to avoid silent authorization failures when devices register with lowercase tags.
  - **Backup Security / Read-Only Mounts**: Source directories mounted into backup containers like Duplicati should be mounted with `read_only = true` to protect live application data from accidental mutation or deletion.

- **Environment Parity & Dynamic Provider Configuration**:
  - By using Terraform's `concat` and conditional expressions, we can dynamically build the provider's `ssh_opts` depending on whether a local SSH key path variable is supplied. This allows developer environments (using local key files) and production CI/CD runners (connecting keylessly via Tailscale SSH) to share the exact same HCL code.

- **Least Privilege and Keyless Access Control**:
  - Relying on machine identity (Tailscale SSH) for CI/CD runners rather than uploading static private SSH keys to GitHub Secrets is an SRE best practice. It eliminates key rotation and management lifecycle overhead, while significantly reducing the repository's security attack surface.

- **Docker Volume Mounts and Host Permissions**:
  - If a host directory mapped in a Docker container volume does not exist when the container starts, the Docker daemon automatically creates it as `root:root`. If the container process runs as a non-root user (e.g. UID 1000), it will face permission denied issues. Pre-creating the directory with correct ownership (`1000:1000`) before starting the container resolves this.
  - For **Uptime Kuma**, the correct internal container path is `/app/data`. Mapping to `/data` results in configs being written to the ephemeral overlay, causing data loss on container replacements.

- **Docker Container DNS Resolution on Tailnets**:
  - Containers that need to query or monitor private Tailscale MagicDNS endpoints (like `*.ts.net`) must have `dns = ["100.100.100.100"]` explicitly declared. Default docker DNS fallback (like `8.8.8.8`) will result in `NXDOMAIN` (`ENOTFOUND`) resolution failures since they lack authority over the private tailnet.

- **Learning focus**
  - The owner is using this project to learn "real" patterns: multi-node infra, secure networking, IaC, SRE practices, CI/CD, and recovery.

---

## User Objective (Owner Profile)

- **Role & background**
  - Current role: Senior Manual QA Analyst.
  - Transitioning into DevOps/SRE engineering.
  - Comfortable with Linux, Docker, home server setups, and automation tools.

- **Learning goals through this project**
  - Gain hands-on experience with:
    - Terraform across multiple providers (Proxmox, Docker, Tailscale).
    - Designing and operating a small but realistic distributed system (multiple x86 nodes).
    - Zero trust networking, access control, and reverse proxying.
    - CI/CD workflows for infrastructure (plan/apply, secret management, key rotation).
    - SRE practices: idempotent provisioning, observability, backups, and disaster recovery.
  - Use the repo as a portfolio piece to demonstrate DevOps thinking and practical skills.

- **How an agent can help next**
  - Refine Terraform modules and clean up provider usage.
  - Propose or implement concrete backup and recovery workflows.
  - Improve CI/CD pipelines and secrets handling.
  - Help iterate on security posture (ACLs, SSH key handling, container exposure).
  - Provide code-level refactors or additional automation scripts as hardware comes online.
