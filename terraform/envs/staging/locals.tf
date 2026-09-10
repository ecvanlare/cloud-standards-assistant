locals {
  workload  = "csa"
  env       = var.environment
  location  = var.location
  loc_short = "uks"

  names = {
    rg       = "rg-${local.workload}-${local.env}-${local.loc_short}"
    vnet     = "vnet-${local.workload}-${local.env}-${local.loc_short}"
    snet_aca = "snet-aca-${local.env}"
    search   = "srch-${local.workload}-${local.env}"
    ais      = "ais-${local.workload}-${local.env}"
    project  = "proj-${local.workload}-${local.env}"
    cae      = "cae-${local.workload}-${local.env}"
    id       = "id-${local.workload}-${local.env}"
    log      = "log-${local.workload}-${local.env}"
    appi     = "appi-${local.workload}-${local.env}"
    ca       = "ca-${local.workload}-${local.env}-serving"
  }

  tags = {
    workload    = local.workload
    environment = local.env
    region      = local.location
    managed_by  = "terraform"
    project     = "cloud-standards-assistant"
  }
}

# Storage (3-24 lowercase alphanumeric) and Key Vault (≤24) need a short unique suffix.
resource "random_string" "suffix" {
  length  = 4
  lower   = true
  upper   = false
  numeric = true
  special = false
}

locals {
  storage_name   = "st${local.workload}${local.env}${random_string.suffix.result}"
  key_vault_name = "kv-${local.workload}-${local.env}-${random_string.suffix.result}"
  acr_name       = "acr${local.workload}${local.env}${random_string.suffix.result}"

  function_apps = {
    asb = {}
    reg = {}
  }

  serving_image = "${module.acr.login_server}/csa-serving:${var.serving_image_tag}"
}

