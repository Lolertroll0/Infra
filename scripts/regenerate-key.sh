#!/bin/bash

# Tailscale Key Rotation Script
# 
# This script automates the rotation of Tailscale Auth Keys for each node role.
# It enforces the Principle of Least Privilege by generating unique keys
# for specific tags defined in the infrastructure ACLs.


# Configuration: Mapping Tailscale Tags to GitHub Secret Names
declare -A NODES=(
  ["tag:orchestrator"]="TAILSCALE_RP4_AUTH_KEY"
  ["tag:mainserver"]="TAILSCALE_MAIN_AUTH_KEY"
  ["tag:voice"]="TAILSCALE_VOICE_AUTH_KEY"
  ["tag:ci"]="TAILSCALE_CI_AUTH_KEY"
)

# Configuration: Expiry time for the keys (Default: 90 days = 7776000 seconds)
EXPIRY_SECONDS=7776000

# 2. Validation: Ensure Tailscale OAuth credentials are present
if [ -z "$TS_API_CLIENT_ID" ] || [ -z "$TS_API_CLIENT_SECRET" ]; then
  echo "❌ Error: TS_API_CLIENT_ID and TS_API_CLIENT_SECRET must be set."
  exit 1
fi

# 3. Get OAuth Access Token
echo "🔑 Requesting Tailscale access token..."
ACCESS_TOKEN=$(curl -s -u "$TS_OAUTH_CLIENT_ID:$TS_OAUTH_CLIENT_SECRET" \
  -d "grant_type=client_credentials" \
  https://api.tailscale.com/api/v2/oauth/token | jq -r '.access_token')

if [ "$ACCESS_TOKEN" == "null" ] || [ -z "$ACCESS_TOKEN" ]; then
  echo "❌ Error: Failed to obtain access token. Check your Client ID and Secret."
  exit 1
fi

# Function to generate a new Tailscale Auth Key
generate_key() {
  local tag=$1
  
  curl -s -H "Authorization: Bearer $ACCESS_TOKEN" -X POST \
    https://api.tailscale.com/api/v2/tailnet/-/keys \
    -d "{
      \"capabilities\": {
        \"devices\": {
          \"create\": {
            \"reusable\": true,
            \"ephemeral\": false,
            \"tags\": [\"$tag\"]
          }
        }
      },
      \"expirySeconds\": $EXPIRY_SECONDS
    }" | jq -r '.key'
}

echo "Starting Tailscale key rotation for all nodes..."

# Iterate through each node role and rotate its key
for tag in "${!NODES[@]}"; do
  SECRET_NAME=${NODES[$tag]}
  
  echo "Processing node: $tag..."
  NEW_KEY=$(generate_key "$tag")

  if [ "$NEW_KEY" != "null" ] && [ -n "$NEW_KEY" ]; then
    # Update the GitHub Secret using the GH CLI
    if gh secret set "$SECRET_NAME" --body "$NEW_KEY"; then
        echo "✅ Successfully rotated key for $tag ($SECRET_NAME)."
    else
        echo "❌ Failed to update GitHub secret $SECRET_NAME."
    fi
  else
    echo "❌ Failed to generate key for $tag. Check your TS_API_ACCESS_TOKEN."
  fi
done

echo "Rotation process complete."