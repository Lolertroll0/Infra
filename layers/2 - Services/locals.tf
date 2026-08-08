locals {
  base_dir   = "/home/${data.terraform_remote_state.infra.outputs.adminUser}"
  data_dir   = "${local.base_dir}/data"
  config_dir = "${local.base_dir}/config"
}
