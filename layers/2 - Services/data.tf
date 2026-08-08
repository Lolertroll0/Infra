data "terraform_remote_state" "infra" {
  backend = "remote"
  config = {
    organization = "Lolertroll-home-Server"
    workspaces = {
      name = "infrastructure-layer"
    }
  }
}
