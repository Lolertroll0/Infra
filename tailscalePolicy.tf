resource "tailscale_acl" "home_mesh_policy" {
  acl = jsonencode({

    nodeAttrs = [
      {
        "target" : ["tag:orchestrator", "tag:mainserver", "tag:voice"]
      }
    ],

    groups = {
      "group:admin" = ["${var.adminEmail}"],
    },

    tagOwners = {
      "tag:orchestrator" = ["group:admin"],
      "tag:mainserver"   = ["group:admin"],
      "tag:voice"        = ["group:admin"],
      "tag:consumer"     = ["group:admin"],
      "tag:ci"           = ["group:admin"],
      "tag:debug"        = ["group:admin"],
    },

    autoApprovers = {
      services = {
        "svc:vaultwarden"   = ["tag:orchestrator"]
        "svc:uptime-kuma"   = ["tag:orchestrator"]
        "svc:homeassistant" = ["tag:orchestrator"]
        "svc:ezbk"          = ["tag:orchestrator"]
      }
    },

    acls = [

      {
        action = "accept"
        src    = ["tag:consumer"]
        dst = [
          "tag:orchestrator:*",
          "svc:vaultwarden:443",
          "svc:uptime-kuma:443",
          "svc:homeassistant:443",
          "svc:ezbk:443",
          "tag:mainserver:8080",
          "tag:mainserver:8006"
        ]
      },

      {
        action = "accept",
        src    = ["tag:orchestrator"],
        dst = [
          "tag:mainserver:8123", # Home Assistant OS
          "tag:mainserver:8080", # ezBookKeeping
        ],
      },

      {
        action = "accept",
        src    = ["tag:mainserver"],
        dst = [
          "tag:voice:10200", # Piper
          "tag:voice:10300", # Whisper
          "tag:voice:11434"  # Ollama API
        ],
      },

      {
        action = "accept",
        src    = ["group:admin"],
        dst    = ["*:*"],
      },
    ],

    ssh = [
      {
        action = "accept",
        src    = ["tag:ci"],
        dst = [
          "tag:orchestrator",
          "tag:mainserver",
          "tag:voice"
        ],
        users = ["${var.adminUser}"],
      },
    ],

  })
}
