locals {
  base_dir   = "/home/${var.adminUser}"
  data_dir   = "${local.base_dir}/data"
  config_dir = "${local.base_dir}/config"
}
