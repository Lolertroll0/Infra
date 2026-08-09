import {
  to = tailscale_acl.home_mesh_policy
  id = var.tailnet
}

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
        "svc:ff3"           = ["tag:orchestrator"]
      }
    },

    acls = [

      {
        action = "accept",
        src    = ["group:admin"],
        dst    = ["*:*"],
      },

      {
        action = "accept",
        src    = ["tag:ci"],
        dst = [
          "tag:orchestrator:22",
          "tag:mainserver:22",
          "tag:voice:22",
          "tag:consumer:22",
          "tag:mainserver:8006"
        ]
      },

      {
        action = "accept"
        src    = ["tag:consumer", "group:admin"]
        dst = [
          "tag:orchestrator:*",
          "tag:mainserver:22",
          "tag:voice:22",

          "svc:vaultwarden:443",
          "svc:uptime-kuma:443",
          "svc:homeassistant:443",
          "svc:ezbk:443",
          "svc:ff3:443"
        ]
      },

      {
        action = "accept",
        src    = ["tag:orchestrator"],
        dst = [
          "tag:mainserver:8123",   # Home Assistant OS
          "tag:mainserver:8080",   # ezBookKeeping Backend
          "svc:ezbk:443",          # ezBookKeeping Virtual Service
          "svc:homeassistant:443", # Home Assistant OS Virtual Service
          "svc:vaultwarden:443",   # Vaultwarden Virtual Service
          "svc:uptime-kuma:443",   # Uptime Kuma Virtual Service
          "svc:ff3:443"            # FF3 Virtual Service
        ],
      },

      {
        action = "accept",
        src    = ["tag:mainserver"],
        dst = [
          "tag:voice:10200", # Piper
          "tag:voice:10300", # Whisper
          "tag:voice:11434"  # Ollama API
        ]
      }
    ],

    ssh = [
      {
        action = "accept",
        src = [
          "tag:consumer",
          "group:admin"
        ],
        dst = [
          "tag:orchestrator",
          "tag:mainserver",
          "tag:voice",
          "tag:consumer",
          "tag:ci",
          "tag:debug"
        ],
        users = ["${var.adminUser}", "root"],
      },
      {
        action = "accept",
        src = [
          "tag:ci",
          "tag:orchestrator",
          "tag:mainserver",
          "tag:voice",
          "tag:debug"
        ],
        dst = [
          "tag:orchestrator",
          "tag:mainserver",
          "tag:voice",
          "tag:consumer",
          "tag:debug"
        ],
        users = ["${var.adminUser}", "root"],
      }
    ],

  })
}
