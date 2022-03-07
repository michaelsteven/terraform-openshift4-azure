resource "azurerm_storage_account" "ignition" {
  count = var.storage_account_name == "" ? 1 : 0

  name                     = "ignition${var.cluster_name}${var.cluster_unique_string}"
  resource_group_name      = var.storage_resource_group
  location                 = var.azure_region
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

data "azurerm_storage_account" "ignition" {
  count = var.ignition_sas_token == "" ? 1 : 0

  name                     = var.storage_account_name != "" ? var.storage_account_name : azurerm_storage_account.ignition[0].name
  resource_group_name      = var.storage_resource_group
}

data "azurerm_storage_account_sas" "ignition" {
  count = var.ignition_sas_token == "" ? 1 : 0

  connection_string = data.azurerm_storage_account.ignition[0].primary_connection_string
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
  }
}

resource "azurerm_storage_container" "ignition" {
  count = var.ignition_sas_token == "" ? 1 : 0

  name                  = "ignition-${var.cluster_id}"
  storage_account_name  = data.azurerm_storage_account.ignition[0].name
  container_access_type = "private"
}

locals {
  installer_workspace     = "${path.root}/installer-files/"
  openshift_installer_url = "${var.openshift_installer_url}/${var.openshift_version}/"
  cluster_nr              = join("", split("-", var.cluster_id))
  ignition_base_uri       = "https://${var.storage_account_name}.blob.core.windows.net/${var.ignition_sas_container_name}"
}

resource "null_resource" "download_binaries" {
  provisioner "local-exec" {
    when = create
    command = templatefile("${path.module}/scripts/download.sh.tmpl", {
      installer_workspace  = local.installer_workspace
      installer_url        = local.openshift_installer_url
      airgapped_enabled    = var.airgapped["enabled"]
      airgapped_repository = var.airgapped["repository"]
      pull_secret          = var.openshift_pull_secret
      openshift_version    = var.openshift_version
      path_root            = path.root
    })
  }
}


resource "null_resource" "generate_manifests" {
  triggers = {
    install_config = data.template_file.install_config_yaml.rendered
  }

  depends_on = [
    null_resource.download_binaries,
    local_file.install_config_yaml,
  ]

  provisioner "local-exec" {
    command = templatefile("${path.module}/scripts/manifests.sh.tmpl", {
      installer_workspace = local.installer_workspace
    })
  }
}

# see templates.tf for generation of yaml config files

resource "null_resource" "generate_ignition" {
  depends_on = [
    null_resource.download_binaries,
    local_file.install_config_yaml,
    null_resource.generate_manifests,
    local_file.cluster-infrastructure-02-config,
    local_file.cluster-dns-02-config,
    local_file.cloud-provider-config,
    local_file.cluster-ingress-default-ingresscontroller,
    local_file.openshift-cluster-api_master-machines,
    local_file.openshift-cluster-api_worker-machineset,
    local_file.openshift-cluster-api_infra-machineset,
    #local_file.ingresscontroller-default,
    local_file.cloud-creds-secret-kube-system,
    #local_file.cluster-scheduler-02-config,
    local_file.cluster-monitoring-configmap,
    #local_file.private-cluster-outbound-service,
  ]

  provisioner "local-exec" {
    command = templatefile("${path.module}/scripts/ignition.sh.tmpl", {
      installer_workspace = local.installer_workspace
      cluster_id          = var.cluster_id
    })
  }
}

resource "azurerm_storage_blob" "ignition-bootstrap" {
  count = var.ignition_sas_token == "" ? 1 : 0

  name                   = "bootstrap.ign"
  source                 = "${local.installer_workspace}/bootstrap.ign"
  storage_account_name   = data.azurerm_storage_account.ignition[0].name
  storage_container_name = azurerm_storage_container.ignition[0].name
  type                   = "Block"
  depends_on = [
    null_resource.generate_ignition
  ]
}

resource "null_resource" "ignition-bootstrap" {
  count = var.ignition_sas_token != "" ? 1 : 0

  provisioner "local-exec" {
    command = <<EOF
"${local.installer_workspace}azcopy" copy "${local.installer_workspace}bootstrap.ign" "${local.ignition_base_uri}/bootstrap.ign?${var.ignition_sas_token}"
EOF
  }

  depends_on = [
    null_resource.generate_ignition
  ]
}

resource "azurerm_storage_blob" "ignition-master" {
  count = var.ignition_sas_token == "" ? 1 : 0

  name                   = "master.ign"
  source                 = "${local.installer_workspace}/master.ign"
  storage_account_name   = data.azurerm_storage_account.ignition[0].name
  storage_container_name = azurerm_storage_container.ignition[0].name
  type                   = "Block"
  depends_on = [
    null_resource.generate_ignition
  ]
}

resource "null_resource" "ignition-master" {
  count = var.ignition_sas_token != "" ? 1 : 0

  provisioner "local-exec" {
    command = <<EOF
"${local.installer_workspace}azcopy" copy "${local.installer_workspace}master.ign" "${local.ignition_base_uri}/master.ign?${var.ignition_sas_token}"
EOF
  }

  depends_on = [
    null_resource.generate_ignition
  ]
}

resource "azurerm_storage_blob" "ignition-worker" {
  count = var.ignition_sas_token == "" ? 1 : 0

  name                   = "worker.ign"
  source                 = "${local.installer_workspace}/worker.ign"
  storage_account_name   = data.azurerm_storage_account.ignition[0].name
  storage_container_name = azurerm_storage_container.ignition[0].name
  type                   = "Block"
  depends_on = [
    null_resource.generate_ignition
  ]
}

resource "null_resource" "ignition-worker" {
  count = var.ignition_sas_token != "" ? 1 : 0

  provisioner "local-exec" {
    command = <<EOF
"${local.installer_workspace}azcopy" copy "${local.installer_workspace}worker.ign" "${local.ignition_base_uri}/worker.ign?${var.ignition_sas_token}"
EOF
  }

  depends_on = [
    null_resource.generate_ignition
  ]
}

resource "azurerm_storage_blob" "auth-kubeconfig" {
  count = var.ignition_sas_token == "" ? 1 : 0

  name                   = "kubeconfig"
  source                 = "${local.installer_workspace}/auth/kubeconfig"
  storage_account_name   = data.azurerm_storage_account.ignition[0].name
  storage_container_name = azurerm_storage_container.ignition[0].name
  type                   = "Block"
  depends_on = [
    null_resource.generate_ignition
  ]
}

resource "null_resource" "auth-kubeconfig" {
  count = var.ignition_sas_token != "" ? 1 : 0

  provisioner "local-exec" {
    command = <<EOF
"${local.installer_workspace}azcopy" copy "${local.installer_workspace}auth/kubeconfig" "${local.ignition_base_uri}/kubeconfig?${var.ignition_sas_token}"
EOF
  }

  depends_on = [
    null_resource.generate_ignition
  ]
}

resource "azurerm_storage_blob" "auth-kubeadmin" {
  count = var.ignition_sas_token == "" ? 1 : 0

  name                   = "kubeadmin-password"
  source                 = "${local.installer_workspace}/auth/kubeadmin-password"
  storage_account_name   = data.azurerm_storage_account.ignition[0].name
  storage_container_name = azurerm_storage_container.ignition[0].name
  type                   = "Block"
  depends_on = [
    null_resource.generate_ignition
  ]
}

resource "null_resource" "auth-kubeadmin" {
  count = var.ignition_sas_token != "" ? 1 : 0

  provisioner "local-exec" {
    command = <<EOF
"${local.installer_workspace}azcopy" copy "${local.installer_workspace}auth/kubeadmin-password" "${local.ignition_base_uri}/kubeadmin-password?${var.ignition_sas_token}"
EOF
  }

  depends_on = [
    null_resource.generate_ignition
  ]
}

data "ignition_config" "master_redirect" {
  replace {
    source = var.ignition_sas_token != "" ? "${local.ignition_base_uri}/master.ign?${var.ignition_sas_token}" : "${azurerm_storage_blob.ignition-master[0].url}${data.azurerm_storage_account_sas.ignition[0].sas}"
  }
}

data "ignition_config" "bootstrap_redirect" {
  replace {
    source = var.ignition_sas_token != "" ? "${local.ignition_base_uri}/bootstrap.ign?${var.ignition_sas_token}" : "${azurerm_storage_blob.ignition-bootstrap[0].url}${data.azurerm_storage_account_sas.ignition[0].sas}"
  }
}

data "ignition_config" "worker_redirect" {
  replace {
    source = var.ignition_sas_token != "" ? "${local.ignition_base_uri}/worker.ign?${var.ignition_sas_token}" : "${azurerm_storage_blob.ignition-worker[0].url}${data.azurerm_storage_account_sas.ignition[0].sas}"
  }
}
