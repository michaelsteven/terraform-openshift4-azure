locals {
  installer_workspace     = "${path.root}/installer-files/"
  openshift_installer_url = "${var.openshift_installer_url}/${var.openshift_version}/"
  cluster_nr              = join("", split("-", var.cluster_id))
}

resource "null_resource" "download_binaries" {

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    when = create
    interpreter = ["/bin/bash"]
    command = "${path.module}/scripts/download.sh.tmpl"
    environment = {
      INSTALLER_WORKSPACE     = local.installer_workspace
      OPENSHIFT_INSTALLER_URL = var.openshift_installer_url
      OPENSHIFT_VERSION       = var.openshift_version
      AIRGAPPED_ENABLED       = var.airgapped["enabled"]
      AIRGAPPED_REPOSITORY    = var.airgapped["repository"]
      PULL_SECRET             = var.openshift_pull_secret
      PATH_ROOT               = path.root
      PROXY_EVAL              = var.proxy_eval
    }
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
    when = create
    interpreter = ["/bin/bash"]
    command = "${path.module}/scripts/manifests.sh.tmpl"
    environment = {
      installer_workspace = local.installer_workspace
    }
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
    local_file.configure-ingress-job,
    #local_file.cloud-creds-secret-kube-system,  TODO: add logic to enable this if var.managed_infrastructure is TRUE
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
  name                   = "bootstrap.ign"
  source                 = "${local.installer_workspace}/bootstrap.ign"
  storage_account_name   = var.storage_account_name
  storage_container_name = var.storage_container_name
  type                   = "Block"
  depends_on = [
    null_resource.generate_ignition
  ]
}

resource "azurerm_storage_blob" "ignition-master" {
  name                   = "master.ign"
  source                 = "${local.installer_workspace}/master.ign"
  storage_account_name   = var.storage_account_name
  storage_container_name = var.storage_container_name
  type                   = "Block"
  depends_on = [
    null_resource.generate_ignition
  ]
}

resource "azurerm_storage_blob" "ignition-worker" {
  name                   = "worker.ign"
  source                 = "${local.installer_workspace}/worker.ign"
  storage_account_name   = var.storage_account_name
  storage_container_name = var.storage_container_name
  type                   = "Block"
  depends_on = [
    null_resource.generate_ignition
  ]
}

resource "azurerm_storage_blob" "auth-kubeconfig" {
  name                   = "kubeconfig"
  source                 = "${local.installer_workspace}/auth/kubeconfig"
  storage_account_name   = var.storage_account_name
  storage_container_name = var.storage_container_name
  type                   = "Block"
  depends_on = [
    null_resource.generate_ignition
  ]
}

data "ignition_config" "master_redirect" {
  replace {
    source = "${azurerm_storage_blob.ignition-master.url}${var.storage_account_sas}"
  }
}

data "ignition_config" "bootstrap_redirect" {
  replace {
    source = "${azurerm_storage_blob.ignition-bootstrap.url}${var.storage_account_sas}"
  }
}

data "ignition_config" "worker_redirect" {
  replace {
    source = "${azurerm_storage_blob.ignition-worker.url}${var.storage_account_sas}"
  }
}
