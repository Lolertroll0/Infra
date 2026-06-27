---
description: pre-merga Validation 
---

Execute a comprehensive pre-merge security validation on the current repository against the production branch.

Threat Assessment: Use @threat-modeling-expert to evaluate the latest diffs for structural vulnerabilities using the STRIDE framework.

Deep Scanning: Use @security-auditor and any available local security integrations (such as StackHawk, Semgrep, etc.) to run strict static and dynamic analysis on the changed code. Focus explicitly on hardcoded secrets, injection flaws, and broken access controls.

Remediation Loop: If high or critical vulnerabilities are found, do not just report them. Enter a remediation loop: analyze the finding, implement a secure fix, and verify the fix by re-running the scan.

Gating & Artifacts: Generate a security_validation_report.md artifact detailing the scan results, any auto-remediated issues, and any outstanding risks. Conclude the report with a strict GO / NO-GO recommendation for merging.
