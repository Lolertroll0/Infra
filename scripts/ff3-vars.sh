#!/bin/bash
set -e

# These variables are injected via the local-exec environment
GDRIVE_URL="googledrive://backup?authid=${GDRIVE_AUTH_ID}"

echo "1. Restoring files on Orchestrator via Duplicati..."
ssh -o StrictHostKeyChecking=no lolertroll@$ORCHESTRATOR "rm -rf /tmp/firefly-secrets /tmp/duplicati-restore && mkdir -p /tmp/firefly-secrets && docker exec duplicati duplicati-cli restore \"$GDRIVE_URL\" --restore-path=\"/tmp/firefly-secrets\" --overwrite=true --passphrase=\"$PASSPHRASE\" && docker cp duplicati:/tmp/firefly-secrets /tmp/duplicati-restore && find /tmp/duplicati-restore -type f -name '*.env' -exec mv {} /tmp/firefly-secrets/ \\; && docker exec duplicati rm -rf /tmp/firefly-secrets"

echo "2. Transferring files from Orchestrator to Target Node..."
mkdir -p ./temp_secrets
scp -o StrictHostKeyChecking=no lolertroll@$ORCHESTRATOR:/tmp/firefly-secrets/* ./temp_secrets/
scp -o StrictHostKeyChecking=no ./temp_secrets/* lolertroll@$TARGET_NODE:/home/lolertroll/config/firefly/

echo "3. Cleaning up temporary secrets..."
rm -rf ./temp_secrets
ssh -o StrictHostKeyChecking=no lolertroll@$ORCHESTRATOR "rm -rf /tmp/firefly-secrets"

echo "Done!"