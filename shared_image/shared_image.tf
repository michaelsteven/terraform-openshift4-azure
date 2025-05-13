locals {
  installer_workspace     = "${path.root}/installer-files/"
  openshift_installer_url = "${var.openshift_installer_url}/${var.openshift_version}/"
  major_version           = join(".", slice(split(".", var.openshift_version), 0, 2))
  ocp_v4_10_plus          = substr(local.major_version, 2, 2) >= 10 ? true : false
  #rhcos_image             = local.ocp_v4_10_plus ?  data.external.vhd_location[0].result["VHD_URL"] : lookup(lookup(jsondecode(data.http.images[0].body), "azure"), "url")
  rhcos_image             = "https://rhcos.blob.core.windows.net/imagebucket/rhcos-417.94.202501301529-0-azure.x86_64.vhd"
}

data "http" "images" {
  count = local.ocp_v4_10_plus ? 0 : 1
  url = "https://raw.githubusercontent.com/openshift/installer/release-${local.major_version}/data/data/rhcos.json"
  request_headers = {
    Accept = "application/json"
  }
}

resource "null_resource" "env_setup" {
  count = local.ocp_v4_10_plus ? 1 : 0

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

data "external" "vhd_location" {
  count = local.ocp_v4_10_plus ? 1 : 0
  program = ["bash", "${path.module}/scripts/get_vhd_path.sh"]

  query = {
    installer_workspace = var.installer_workspace
  }

  depends_on = [
    null_resource.env_setup
  ]
}

resource "azurerm_image" "cluster" {
  name                = "${var.cluster_name}-${var.cluster_unique_string}"
  resource_group_name = var.cluster_resource_group_name
  location            = var.region

  os_disk {
    os_type  = "Linux"
    os_state = "Generalized"
    managed_disk_id = azurerm_managed_disk.rhcos_disk.id
  }

  depends_on = [
    null_resource.update_disk
  ]   
}

resource "azurerm_managed_disk" "rhcos_disk" {
  name                 = "coreos-${var.openshift_version}-${var.cluster_unique_string}-vhd"
  location             = var.region
  resource_group_name  = var.cluster_resource_group_name
  storage_account_type = "Standard_LRS"
  create_option        = "Upload"
  upload_size_bytes    = "17179869696"

}

resource "azurerm_managed_disk_sas_token" "disk_token" {
  managed_disk_id     = azurerm_managed_disk.rhcos_disk.id
  duration_in_seconds = 600
  access_level        = "Write"
}

resource "null_resource" "update_disk" {
  provisioner "local-exec" {
    command = "${path.module}/scripts/update_disk.sh"
    interpreter = ["/bin/bash"]
    environment = {
      INSTALLER_WORKSPACE = var.installer_workspace
      SUBSCRIPTION_ID     = var.subscription_id
      TENANT_ID           = var.tenant_id
      CLIENT_ID           = var.client_id
      CLIENT_SECRET       = var.client_secret
      RESOURCE_GROUP_NAME = var.cluster_resource_group_name
      OPENSHIFT_VERSION   = var.openshift_version
      REGION              = var.region
      RHCOS_IMAGE_URL     = local.rhcos_image
      BASH_DEBUG          = var.bash_debug
      CLUSTER_ID          = var.cluster_unique_string
      PROXY_EVAL          = var.proxy_eval
      ACCESS_SAS          = azurerm_managed_disk_sas_token.disk_token.sas_url
    }
  }
}
