# Agent Rules

## Security & Credentials
- **Do NOT write or add sensitive data** (such as real passwords, API tokens, secret keys, private credentials, or certificates) to any files in the workspace. This restriction applies universally, including to files that are ignored by Git via `.gitignore` (e.g., `local.auto.tfvars`, `.env` files, or local configuration scripts).
- Always use dummy values, placeholders, or template files. If real credentials or secrets are needed, instruct the user to populate them manually on their host system or environment.
