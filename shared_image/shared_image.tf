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

resource "null_resource" "download_binaries" {
  provisioner "local-exec" {
    when = create
    command = templatefile("${path.module}/scripts/download.sh.tmpl", {
      installer_workspace  = local.installer_workspace
    })
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -rf ./installer-files"
  }
}

resource "null_resource" "rhcos_disk" {
  triggers = {
    installer_workspace = local.installer_workspace
    openshift_version = var.openshift_version
    cluster_resource_group_name = var.cluster_resource_group_name
  }

  provisioner "local-exec" {
    when = create
    command = <<EOF
    az disk create -n "coreos-${var.openshift_version}-vhd" -g "${var.cluster_resource_group_name}" -l "${var.region}" --os-type Linux --for-upload --upload-size-bytes $(curl -sI ${local.rhcos_image} | grep -i Content-Length | awk '{print $2}') --sku standard_lrs
  EOF
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOF
    az disk delete -n "coreos-${self.triggers.openshift_version}-vhd" -g "${self.triggers.cluster_resource_group_name}" -y
  EOF
  }  

  depends_on = [
    null_resource.download_binaries
  ]
}

data "azurerm_managed_disk" "rhcos_disk" {
  name                = "coreos-${var.openshift_version}-vhd"
  resource_group_name = var.cluster_resource_group_name
  depends_on = [
    null_resource.rhcos_disk
  ]
}

data "external" "rhcos_disk_sas" {
  program = ["bash","${path.cwd}/${path.module}/scripts/get_disk_sas.sh"]
  working_dir = local.installer_workspace
  query = {
    openshift_version = var.openshift_version
    resource_group_name = var.cluster_resource_group_name
  }
  depends_on = [
    null_resource.rhcos_disk
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

resource "null_resource" "rhcos_disk_revoke" {
  provisioner "local-exec" {
    when = create
    command = <<EOF
    az disk revoke-access -n "coreos-${var.openshift_version}-vhd" -g "${var.cluster_resource_group_name}"
  EOF
  }
  depends_on = [
    null_resource.rhcos_disk_copy
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
    null_resource.rhcos_disk_revoke
  ]  
}
