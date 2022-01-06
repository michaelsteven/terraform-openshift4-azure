locals {
  major_version    = join(".", slice(split(".", var.openshift_version), 0, 2))
  rhcos_image      = lookup(lookup(jsondecode(data.http.images.body), "azure"), "url")
  vhd_exists       = var.vhd_exists && var.storage_account_exists && !var.storage_account_sas
  # There is an issue creating an azure image from a SAS url, see the following
  # https://github.com/Azure/azure-cli/issues/16109  
  image_uri        = "https://${var.storage_account_name}.blob.core.windows.net/${var.container_name_vhd}/rhcos${var.cluster_unique_string}.vhd"
  image_sas_uri    = "${local.image_uri}?${var.sas_token_vhd}"
  blob_uri         = local.vhd_exists ? (var.storage_account_sas ? var.storage_blob_sas_uri : data.azurerm_storage_blob.rhcos_image[0].url) : (var.storage_account_sas ? local.image_uri : azurerm_storage_blob.rhcos_image[0].url)
}

data "http" "images" {
  url = "https://raw.githubusercontent.com/openshift/installer/release-${local.major_version}/data/data/rhcos.json"
  request_headers = {
    Accept = "application/json"
  }
}

resource "azurerm_storage_container" "vhd" {
  count = !var.vhd_exists && !var.storage_account_sas ? 1 : 0

  name                 = "vhd${var.cluster_id}"
  storage_account_name = var.storage_account_name
}

resource "azurerm_storage_blob" "rhcos_image" {
  count = !var.vhd_exists && !var.storage_account_sas ? 1 : 0

  name                   = "rhcos${var.cluster_unique_string}.vhd"
  storage_account_name   = var.storage_account_name
  storage_container_name = azurerm_storage_container.vhd[0].name
  type                   = "Page"
  source_uri             = local.rhcos_image
  metadata               = tomap({"source_uri" = local.rhcos_image})
}

data "azurerm_storage_blob" "rhcos_image" {
  count = var.vhd_exists && !var.storage_account_sas ? 1 : 0 

  name                   = var.storage_blob_name
  storage_account_name   = var.storage_account_name
  storage_container_name = azurerm_storage_container.vhd[0].name
}

resource "null_resource" "rhcos_image" {
  count = !var.vhd_exists && var.storage_account_sas ? 1 : 0

  provisioner "local-exec" {
    command = <<EOF
# Create workspace directory if it does not exist
test -e ${var.installer_workspace} || mkdir -p ${var.installer_workspace}

# Install azcopy
curl -L https://aka.ms/downloadazcopy-v10-linux -o ${var.installer_workspace}/downloadazcopy-v10-linux
tar zxvf ${var.installer_workspace}/downloadazcopy-v10-linux -C ${var.installer_workspace} --wildcards *azcopy --strip-components 1

# Copy rhcos image to SAS storage
"${var.installer_workspace}azcopy" copy "${local.rhcos_image}" "${local.image_sas_uri}"
EOF
  }
}

resource "time_sleep" "wait_15_seconds" {
  depends_on = [null_resource.rhcos_image]

  create_duration = "15s"
}

resource "azurerm_image" "cluster" {
  depends_on = [time_sleep.wait_15_seconds]

  name                = var.cluster_id
  resource_group_name = var.resource_group_name
  location            = var.azure_region

  os_disk {
    os_type  = "Linux"
    os_state = "Generalized"
    blob_uri = local.blob_uri
  }
}
