data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "key_vault" {
  name                       = "${substr(var.resource_prefix, 0, 10)}-${var.random_string}-kv"
  location                   = var.region
  resource_group_name        = var.resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                    = "premium"
  enabled_for_disk_encryption = true
  purge_protection_enabled    = true
}

resource "azurerm_key_vault_key" "disk_key" {
  name         = "${var.cluster_id}-disk-encryption-key"
  key_vault_id = azurerm_key_vault.key_vault.id
  key_type     = "RSA"
  key_size     = 2048

  depends_on = [
    azurerm_key_vault_access_policy.sp_access
  ]

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]
}

resource "azurerm_disk_encryption_set" "des" {
  name                = "${var.cluster_id}-des"
  location            = var.region
  resource_group_name = var.resource_group_name
  key_vault_key_id    = azurerm_key_vault_key.disk_key.id

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_key_vault_access_policy" "cluster_disk" {
  key_vault_id = azurerm_key_vault.key_vault.id

  tenant_id = azurerm_disk_encryption_set.des.identity[0].tenant_id
  object_id = azurerm_disk_encryption_set.des.identity[0].principal_id

  key_permissions = [
    "Get",
    "WrapKey",
    "UnwrapKey",
  ]

  depends_on = [
    azurerm_disk_encryption_set.des
  ]
}


resource "azurerm_key_vault_access_policy" "sp_access" {
  key_vault_id = azurerm_key_vault.key_vault.id

  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = data.azurerm_client_config.current.object_id

  key_permissions = [
    "Create",
    "Delete",
    "Get",
    "Purge",
    "Recover",
    "Update",
    "List",
    "Decrypt",
    "Sign",
    "GetRotationPolicy",
  ]
}