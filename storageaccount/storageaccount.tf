resource "azurerm_storage_account" "ignition" {
  name                     = "${var.cluster_name}${var.cluster_unique_string}ignition"
  resource_group_name      = var.resource_group_name
  location                 = var.azure_region
  account_tier             = "Standard"
  account_replication_type = "LRS"
  public_network_access_enabled = false
}

data "azurerm_storage_account" "ignition" {
  name                     = azurerm_storage_account.ignition.name
  resource_group_name      = var.resource_group_name
}

data "azurerm_storage_account_sas" "ignition" {
  connection_string = data.azurerm_storage_account.ignition.primary_connection_string
  https_only        = true

  resource_types {
    service   = false
    container = false
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  start = timestamp()

  expiry = timeadd(timestamp(), "24h")

  permissions {
    read    = true
    list    = true
    create  = false
    add     = false
    delete  = false
    process = false
    write   = false
    update  = false
    filter  = false
    tag     = false
  }
}

resource "azurerm_storage_container" "ignition" {
  name                  = "ignition-${var.cluster_id}"
  storage_account_name  = data.azurerm_storage_account.ignition.name
  container_access_type = "private"
}

resource "azurerm_private_endpoint" "storage_private_endpoint" {
    name                = "${var.resource_prefix}-pe"
    location            = var.azure_region
    resource_group_name = var.resource_group_name
    subnet_id           = var.private_endpoint_subnet_id

    private_service_connection {
        name                           = "${var.resource_prefix}-ignition-storate-private-endpointce-connection"
        private_connection_resource_id = data.azurerm_storage_account.ignition.id
        is_manual_connection           = false
        subresource_names              = ["blob"]
    }
}