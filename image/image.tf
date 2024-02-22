locals {
  installer_workspace     = "${path.root}/installer-files/"
  openshift_installer_url = "${var.openshift_installer_url}/${var.openshift_version}/"
  major_version          = join(".", slice(split(".", var.openshift_version), 0, 2))
  rhcos_image            = data.external.vhd_location.result["VHD_URL"]
}

data "external" "vhd_location" {
  program = ["bash", "${path.module}/scripts/get_vhd_path.sh"]

  query = {
    installer_workspace = var.installer_workspace
  }

  depends_on = [
    null_resource.env_setup
  ]
}

resource "null_resource" "env_setup" {
  provisioner "local-exec" {
    command = "${path.module}/scripts/env_setup.sh"
    interpreter = ["/bin/bash"]
    environment = {
      INSTALLER_WORKSPACE = local.installer_workspace
      OPENSHIFT_INSTALLER_URL = local.openshift_installer_url
      OPENSHIFT_VERSION = var.openshift_version
    }
  }
}

resource "azurerm_storage_account" "image" {
  count = var.storage_account_name == "" ? 1 : 0

  name                     = "image${var.cluster_name}${var.cluster_unique_string}"
  resource_group_name      = var.storage_resource_group_name
  location                 = var.region
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

data "azurerm_storage_account" "image" {
  name                     = var.storage_account_name != "" ? var.storage_account_name : azurerm_storage_account.image[0].name
  resource_group_name      = var.storage_resource_group_name
}

resource "azurerm_storage_container" "vhd" {
  count = var.image_blob_uri == "" && var.image_container_name == "" ? 1 : 0

  name                 = "vhd-${var.cluster_id}"
  storage_account_name = data.azurerm_storage_account.image.name
}

data "azurerm_storage_container" "vhd" {
  name                     = var.image_blob_uri == "" && var.image_container_name != "" ? var.image_container_name : azurerm_storage_container.vhd[0].name
  storage_account_name     = data.azurerm_storage_account.image.name
}

resource "azurerm_storage_blob" "rhcos_image" {
  count = var.image_blob_uri == "" && var.image_blob_name == "" ? 1 : 0

  name                   = "rhcos-${var.cluster_unique_string}.vhd"
  storage_account_name   = data.azurerm_storage_account.image.name
  storage_container_name = data.azurerm_storage_container.vhd.name
  type                   = "Page"
  source_uri             = local.rhcos_image
  metadata               = tomap({"source_uri" = local.rhcos_image})
}

data "azurerm_storage_blob" "rhcos_image" {
  name                   = var.image_blob_uri == "" && var.image_blob_name != "" ? var.image_blob_name : azurerm_storage_blob.rhcos_image[0].name
  storage_account_name   = data.azurerm_storage_account.image.name
  storage_container_name = data.azurerm_storage_container.vhd.name
}

resource "azurerm_image" "cluster" {
  name                = var.cluster_id
  resource_group_name = var.cluster_resource_group_name
  location            = var.region

  os_disk {
    os_type  = "Linux"
    os_state = "Generalized"
    blob_uri = var.image_blob_uri != "" ? var.image_blob_uri : data.azurerm_storage_blob.rhcos_image.url
  }
}
