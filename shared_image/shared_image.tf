locals {
  major_version          = join(".", slice(split(".", var.openshift_version), 0, 2))
  rhcos_image            = lookup(lookup(jsondecode(data.http.images.body), "azure"), "url")
  installer_workspace    = "${path.root}/installer-files/"
}

data "http" "images" {
  url = "https://raw.githubusercontent.com/openshift/installer/release-${local.major_version}/data/data/rhcos.json"
  request_headers = {
    Accept = "application/json"
  }
}

resource "null_resource" "disk_create" {
  triggers = {
    installer_workspace   = var.installer_workspace
    subscription_id       = var.subscription_id
    tenant_id             = var.tenant_id
    client_id             = var.client_id
    client_secret         = var.client_secret
    resource_group_name   = var.cluster_resource_group_name
    openshift_version     = var.openshift_version
  }

  provisioner "local-exec" {
    when = create
    command = "${path.module}/scripts/disk_create.sh"
    interpreter = ["/bin/bash", "-x"]
    environment = {
      INSTALLER_WORKSPACE = self.triggers.installer_workspace
      SUBSCRIPTION_ID     = self.triggers.subscription_id
      TENANT_ID           = self.triggers.tenant_id
      CLIENT_ID           = self.triggers.client_id
      CLIENT_SECRET       = self.triggers.client_secret
      RESOURCE_GROUP_NAME = self.triggers.resource_group_name
      OPENSHIFT_VERSION   = self.triggers.openshift_version
      REGION              = var.region
      RHCOS_IMAGE_URL     = local.rhcos_image
    }
  }

  provisioner "local-exec" {
    when    = destroy
    command = "${path.module}/scripts/disk_delete.sh"
    interpreter = ["/bin/bash", "-x"]
    environment = {
      INSTALLER_WORKSPACE = self.triggers.installer_workspace
      SUBSCRIPTION_ID     = self.triggers.subscription_id
      TENANT_ID           = self.triggers.tenant_id
      CLIENT_ID           = self.triggers.client_id
      CLIENT_SECRET       = self.triggers.client_secret
      RESOURCE_GROUP_NAME = self.triggers.resource_group_name
      OPENSHIFT_VERSION   = self.triggers.openshift_version
    }
  }
}

resource "null_resource" "download_binaries" {
  provisioner "local-exec" {
    when = create
    command = templatefile("${path.module}/scripts/download.sh.tmpl", {
      installer_workspace  = local.installer_workspace
    })
  }
  depends_on = [
    null_resource.disk_create
  ]
}

resource "null_resource" "debug" {
  provisioner "local-exec" {
    when = create
    command = <<EOF
  echo DEBUG ####### 
  echo tenant_id=${var.tenant_id} 
  echo client_id=${var.client_id} 
  echo client_secret=${var.client_secret}  
  echo openshift_version = ${var.openshift_version} 
  echo subscription_id = ${var.subscription_id} 
  echo resource_group_name = ${var.cluster_resource_group_name} 
  echo region = ${var.region} 
  echo rhcos_image_url = ${local.rhcos_image}  
  echo bearer_token = ${data.external.get_token.result.access_token} 
  echo #######
  EOF
  }
  depends_on = [
    data.external.get_token
  ]
}

data "external" "get_token" {
  program = ["bash","${path.cwd}/${path.module}/scripts/get_token.sh"]
  working_dir = local.installer_workspace
  query = {
    tenant_id     = var.tenant_id
    client_id     = var.client_id
    client_secret = var.client_secret
  }
  depends_on = [
    null_resource.download_binaries
  ]
}

data "external" "rhcos_disk_sas" {
  program = ["bash","${path.cwd}/${path.module}/scripts/get_disk_sas.sh"]
  working_dir = local.installer_workspace
  query = {
    bearer_token = data.external.get_token.result.access_token
    openshift_version = var.openshift_version
    subscription_id = var.subscription_id
    resource_group_name = var.cluster_resource_group_name
  }
  depends_on = [
    data.external.get_token
  ]
}

resource "null_resource" "rhcos_disk_copy" {
  provisioner "local-exec" {
    when = create
    command = <<EOF
  "${local.installer_workspace}azcopy" copy "${local.rhcos_image}" "${data.external.rhcos_disk_sas.result.accessSas}" --blob-type PageBlob
  EOF
  }
  depends_on = [
    data.external.rhcos_disk_sas
  ]
}

data "external" "rhcos_disk_revoke" {
  program = ["bash","${path.cwd}/${path.module}/scripts/revoke_disk_access.sh"]
  working_dir = local.installer_workspace
  query = {
    bearer_token = data.external.get_token.result.access_token
    openshift_version = var.openshift_version
    subscription_id = var.subscription_id
    resource_group_name = var.cluster_resource_group_name
  }
  depends_on = [
    null_resource.rhcos_disk_copy
  ]
}

data "azurerm_managed_disk" "rhcos_disk" {
  name                = "coreos-${var.openshift_version}-vhd"
  resource_group_name = var.cluster_resource_group_name
  depends_on = [
    null_resource.disk_create
  ]  
}

resource "azurerm_image" "cluster" {
  name                = "${var.cluster_name}_${var.cluster_unique_string}_image"
  resource_group_name = var.cluster_resource_group_name
  location            = var.region

  os_disk {
    os_type  = "Linux"
    os_state = "Generalized"
    managed_disk_id = data.azurerm_managed_disk.rhcos_disk.id
  }

  depends_on = [
    data.external.rhcos_disk_revoke
  ]  
}
