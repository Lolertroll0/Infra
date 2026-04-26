resource "tailscale_acl" "home_mesh_policy" {
  acl = jsonencode({
    
    nodeAttrs = [
      {
        "target": ["tag:orchestrator", "tag:mainServer"],
        "attr": ["dns-subdomain-resolve"]
      }
    ],

    groups = {
      "group:admin" = ["${var.adminEmail}"],
    },

    tagOwners = {
      "tag:orchestrator" = ["group:admin"],
      "tag:mainServer"   = ["group:admin"],
      "tag:voice"        = ["group:admin"],
      "tag:consumer"     = ["group:admin"],
    },

    acls = [

      { 
        action = "accept" 
        src = ["tag:consumer"] 
        dst = ["tag:orchestrator:*"] 
      },
        
      {
        action = "accept",
        src    = ["tag:consumer"],
        dst    = ["tag:orchestrator:*"],
      },

      {
        action = "accept",
        src    = ["tag:orchestrator"],
        dst    = [
          "tag:mainServer:8123", 
          "tag:voice:11434", # Ollama API
          "tag:voice:8080"   # Ollama WebUI
        ],
      },

      {
        action = "accept",
        src    = ["tag:mainServer"],
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
          "tag:mainServer", 
          "tag:voice"
        ],
        users  = ["root", "${var.adminUser}", "admin"],
      },
    ],

  })
}