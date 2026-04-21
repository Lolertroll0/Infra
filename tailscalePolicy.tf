resource "tailscale_acl" "home_mesh_policy" {
  acl = jsonencode({

    groups = {
      "group:admin" = ["${var.global.adminEmail}"],
    },

    tagOwners = {
      "tag:orchestrator" = ["group:admin"],
      "tag:automation"   = ["group:admin"],
      "tag:voice"        = ["group:admin"],
      # TODO: add consumer tags
    },

    acls = [

      # TODO: add ACLs for consumers

      {
        action = "accept",
        src    = ["tag:orchestrator"],
        dst    = [
          "tag:automation:8123", 
          "tag:voice:11434", # Ollama API
          "tag:voice:10300", # Piper
          "tag:voice:10200", # Whisper
          "tag:voice:8080"   # Ollama WebUI
        ],
      },

      {
        action = "accept",
        src    = ["tag:automation"],
        dst    = [
          "tag:voice:10300", # Piper
          "tag:voice:10200", # Whisper
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
        src    = ["group:admin"],
        dst    = [
          "tag:orchestrator", 
          "tag:automation", 
          "tag:voice"
        ],
        users  = ["root", "${var.global.adminUser}", "admin"],
      },
    ],

  })
}