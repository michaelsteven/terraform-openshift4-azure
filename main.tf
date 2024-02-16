provider "azurerm" {
  features {}
  # comment this out if using ARM environment variables for authentication
  #subscription_id = var.azure_subscription_id
  #client_id       = var.azure_client_id
  #client_secret   = var.azure_client_secret
  #tenant_id       = var.azure_tenant_id
  ####
  environment     = var.azure_environment
  partner_id = "06f07fff-296b-5beb-9092-deab0c6bb8ea"
}

resource "null_resource" "installer_workspace" {
  triggers = {
    installer_workspace   = local.installer_workspace
  }

  provisioner "local-exec" {
    when = create
    command = "${path.root}/scripts/installer_workspace.sh"
    interpreter = ["/bin/bash"]
    environment = {
      INSTALLER_WORKSPACE = self.triggers.installer_workspace
      OPENSHIFT_INSTALLER_URL = var.openshift_installer_url
      OPENSHIFT_VERSION = var.openshift_version
      PROXY_EVAL = var.no_proxy_test
    }
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -rf ${self.triggers.installer_workspace}"
  }

}

data "azurerm_client_config" "current" {
}

data "external" "get_azure_client_secret" {
  depends_on = [null_resource.installer_workspace]

  program = ["bash", "${path.root}/scripts/get_client_secret.sh" ]
  query = {
    installer_workspace = local.installer_workspace
  }
}

resource "random_string" "cluster_id" {
  length  = 5
  special = false
  upper   = false
}

# SSH Key for VMs
resource "tls_private_key" "installkey" {
  count     = var.openshift_ssh_key == "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "write_private_key" {
  count           = var.openshift_ssh_key == "" ? 1 : 0
  content         = tls_private_key.installkey[0].private_key_pem
  filename        = "${path.root}/installer-files/artifacts/openshift_rsa"
  file_permission = 0600
}

resource "local_file" "write_public_key" {
  content         = local.public_ssh_key
  filename        = "${path.root}/installer-files/artifacts/openshift_rsa.pub"
  file_permission = 0600
}

data "template_file" "azure_sp_json" {
  template = <<EOF
{
  "subscriptionId":"${local.azure_subscription_id}",
  "clientId":"${local.azure_client_id}",
  "clientSecret":"${local.azure_client_secret}",
  "tenantId":"${local.azure_tenant_id}"
}
EOF
}

resource "local_file" "azure_sp_json" {
  content  = data.template_file.azure_sp_json.rendered
  filename = pathexpand("~/.azure/osServicePrincipal.json")
}

data "external" "get_network_configuration" {
  count = var.azure_preexisting_network && var.azure_network_introspection ? 1 : 0

  program = ["bash", "${path.root}/scripts/get_network_config.sh" ]
  query = {
    installer_workspace = local.installer_workspace
    azure_subscription_id = local.azure_subscription_id
    azure_tenent_id = local.azure_tenant_id
    azure_client_id = local.azure_client_id
    azure_client_secret = local.azure_client_secret
    azure_resource_group_name_substring = var.azure_resource_group_name_substring
    azure_control_plane_subnet_substring = var.azure_control_plane_subnet_substring
    azure_compute_subnet_substring = var.azure_compute_subnet_substring
  }
}

locals {
  cluster_id = "${var.cluster_name}-${random_string.cluster_id.result}"
  tags = merge(
    {
      "kubernetes.io_cluster.${local.cluster_id}" = "owned"
    },
    var.azure_extra_tags,
  )
  azure_network_resource_group_name   = var.azure_preexisting_network ? (var.azure_network_introspection ? data.external.get_network_configuration[0].result.resource_group_name : (var.azure_network_resource_group_name != null ? var.azure_network_resource_group_name : data.azurerm_resource_group.main.name)) : data.azurerm_resource_group.main.name
  azure_virtual_network               = var.azure_preexisting_network ? (var.azure_network_introspection ? data.external.get_network_configuration[0].result.virtual_network : (var.azure_virtual_network != null ? var.azure_virtual_network : "${local.cluster_id}-vnet")) : "${local.cluster_id}-vnet"
  azure_control_plane_subnet          = var.azure_preexisting_network ? (var.azure_network_introspection ? data.external.get_network_configuration[0].result.control_plane_subnet : (var.azure_control_plane_subnet != null ? var.azure_control_plane_subnet : "${local.cluster_id}-master-subnet")) : "${local.cluster_id}-master-subnet"
  azure_compute_subnet                = var.azure_preexisting_network ? (var.azure_network_introspection ? data.external.get_network_configuration[0].result.compute_subnet : (var.azure_compute_subnet != null ? var.azure_compute_subnet : "${local.cluster_id}-worker-subnet")) : "${local.cluster_id}-worker-subnet"
  machine_v4_cidrs                    = var.azure_network_introspection ? tolist(["${data.external.get_network_configuration[0].result.virtual_network_cidr}"]) : var.machine_v4_cidrs
  public_ssh_key                      = var.openshift_ssh_key == "" ? tls_private_key.installkey[0].public_key_openssh : var.openshift_ssh_key
  major_version                       = join(".", slice(split(".", var.openshift_version), 0, 2))
  installer_workspace                 = "${path.cwd}/installer-files/"
  azure_image_id                      = var.azure_image_id != "" ? var.azure_image_id : (var.azure_shared_image ? module.shared_image[0].shared_image_id : module.image[0].image_cluster_id)
  azure_bootlogs_storage_account_name = var.use_bootlogs_storage_account ? ( var.azure_bootlogs_sas_token != "" ? var.azure_bootlogs_storage_account_name : data.azurerm_storage_account.bootlogs[0].name ) : ""
  azure_bootlogs_base_uri             = "https://${local.azure_bootlogs_storage_account_name}.blob.core.windows.net/"
  azure_bootlogs_storage_account_uri  = var.use_bootlogs_storage_account ? ( var.azure_bootlogs_sas_token != "" ? "${local.azure_bootlogs_base_uri}?${var.azure_bootlogs_sas_token}" : data.azurerm_storage_account.bootlogs[0].primary_blob_endpoint ) : ""
  azure_subscription_id               = var.azure_subscription_id != "" ? var.azure_subscription_id : data.azurerm_client_config.current.subscription_id
  azure_tenant_id                     = var.azure_tenant_id != "" ? var.azure_tenant_id : data.azurerm_client_config.current.tenant_id
  azure_client_id                     = var.azure_client_id != "" ? var.azure_client_id : data.azurerm_client_config.current.client_id
  azure_client_secret                 = var.azure_client_secret != "" ? var.azure_client_secret : data.external.get_azure_client_secret.result.client_secret
}

module "image" {
  count                             = !var.azure_shared_image && var.azure_image_id == "" ? 1 : 0
  source                            = "./image"
  
  openshift_version                 = var.openshift_version
  cluster_name                      = var.cluster_name
  cluster_unique_string             = random_string.cluster_id.result
  cluster_id                        = local.cluster_id
  cluster_resource_group_name       = data.azurerm_resource_group.main.name
  storage_resource_group_name       = data.azurerm_resource_group.image_storage.name
  storage_account_name              = var.azure_image_storage_account_name
  region                            = var.azure_region
  image_blob_uri                    = var.azure_image_blob_uri
  image_container_name              = var.azure_image_container_name
  image_blob_name                   = var.azure_image_blob_name
}

module "shared_image" {
  count                             = var.azure_shared_image && var.azure_image_id == "" ? 1 : 0
  source                            = "./shared_image"
  depends_on                        = [null_resource.installer_workspace]

  openshift_installer_url           = var.openshift_installer_url
  openshift_version                 = var.openshift_version
  subscription_id                   = local.azure_subscription_id
  tenant_id                         = local.azure_tenant_id
  client_id                         = local.azure_client_id
  client_secret                     = local.azure_client_secret
  cluster_name                      = var.cluster_name
  cluster_unique_string             = random_string.cluster_id.result
  cluster_resource_group_name       = data.azurerm_resource_group.main.name
  region                            = var.azure_region
  shared_image_repo_name            = var.azure_shared_image_repo_name
  shared_image_name                 = var.azure_shared_image_name
  installer_workspace               = null_resource.installer_workspace.triggers.installer_workspace
  bash_debug                        = var.bash_debug
  proxy_eval                        = var.no_proxy_test   
}

module "vnet" {
  source              = "./vnet"
  resource_group_name = data.azurerm_resource_group.main.name
  vnet_v4_cidrs       = local.machine_v4_cidrs
  vnet_v6_cidrs       = var.machine_v6_cidrs
  cluster_id          = local.cluster_id
  region              = var.azure_region
  dns_label           = local.cluster_id

  preexisting_network         = var.azure_preexisting_network
  network_resource_group_name = local.azure_network_resource_group_name
  virtual_network_name        = local.azure_virtual_network
  master_subnet               = local.azure_control_plane_subnet
  worker_subnet               = local.azure_compute_subnet
  private                     = var.azure_private
  outbound_udr                = var.azure_outbound_user_defined_routing

  use_ipv4                  = var.use_ipv4 || var.azure_emulate_single_stack_ipv6
  use_ipv6                  = var.use_ipv6
  emulate_single_stack_ipv6 = var.azure_emulate_single_stack_ipv6
  dns_api_ip                = var.api_and_api-int_dns_ip
  dns_apps_ip               = var.apps_dns_ip
}

module "dns" {
  count                           = !var.openshift_byo_dns && var.openshift_dns_provider == "azure" ? 1 : 0
  source                          = "./dns"

  cluster_domain                  = "${var.cluster_name}.${var.base_domain}"
  cluster_id                      = local.cluster_id
  base_domain                     = var.base_domain
  virtual_network_id              = module.vnet.virtual_network_id
  external_lb_fqdn_v4             = module.vnet.public_lb_pip_v4_fqdn
  external_lb_fqdn_v6             = module.vnet.public_lb_pip_v6_fqdn
  internal_lb_ipaddress_v4        = module.vnet.internal_lb_ip_v4_address
  internal_lb_ipaddress_v6        = module.vnet.internal_lb_ip_v6_address
  resource_group_name             = data.azurerm_resource_group.main.name
  base_domain_resource_group_name = var.azure_base_domain_resource_group_name
  private                         = module.vnet.private

  use_ipv4                        = var.use_ipv4 || var.azure_emulate_single_stack_ipv6
  use_ipv6                        = var.use_ipv6
  emulate_single_stack_ipv6       = var.azure_emulate_single_stack_ipv6
}

data "external" "infoblox_env" {
  program = ["bash", "${path.module}/scripts/infoblox_env.sh"]
}

provider "infoblox" {
  username                        = var.infoblox_username != "" ? var.infoblox_username : data.external.infoblox_env.result["infoblox_username"]
  password                        = var.infoblox_password != "" ? var.infoblox_password : data.external.infoblox_env.result["infoblox_password"]
  server                          = var.infoblox_fqdn
  wapi_version                    = var.infoblox_wapi_version
  pool_connections                = var.infoblox_pool_connections
}

module "infoblox_dns" {
  count                           = var.azure_private && var.openshift_dns_provider == "infoblox" ? 1 : 0
  source                          = "./infoblox_dns"

  infoblox_fqdn                   = var.infoblox_fqdn
  infoblox_username               = var.infoblox_username != "" ? var.infoblox_username : data.external.infoblox_env.result["infoblox_username"]
  infoblox_password               = var.infoblox_password != "" ? var.infoblox_password : data.external.infoblox_env.result["infoblox_password"]
  infoblox_allow_any              = var.infoblox_allow_any
  infoblox_apps_dns_entries       = var.infoblox_apps_dns_entries
  cluster_name                    = var.cluster_name
  base_domain                     = var.base_domain
  internal_lb_ipaddress_v4        = module.vnet.internal_lb_ip_v4_address
  internal_lb_ipaddress_v6        = module.vnet.internal_lb_ip_v6_address
  internal_lb_apps_ipaddress_v4   = module.vnet.internal_lb_apps_ip_v4_address
  internal_lb_apps_ipaddress_v6   = module.vnet.internal_lb_apps_ip_v6_address

  use_ipv4                        = var.use_ipv4
  use_ipv6                        = var.use_ipv6
}

module "ignition" {
  source                        = "./ignition"
  depends_on                    = [module.image, module.shared_image, local_file.azure_sp_json, null_resource.installer_workspace]
  base_domain                   = var.base_domain
  openshift_version             = var.openshift_version
  master_count                  = var.master_count
  cluster_name                  = var.cluster_name
  cluster_unique_string         = random_string.cluster_id.result
  cluster_network_cidr          = var.openshift_cluster_network_cidr
  cluster_network_host_prefix   = var.openshift_cluster_network_host_prefix
  machine_cidr                  = local.machine_v4_cidrs[0]
  service_network_cidr          = var.openshift_service_network_cidr
  azure_dns_resource_group_name = var.azure_base_domain_resource_group_name
  openshift_pull_secret         = var.openshift_pull_secret
  openshift_pull_secret_string  = var.openshift_pull_secret_string
  public_ssh_key                = chomp(local.public_ssh_key)
  cluster_id                    = local.cluster_id
  resource_group_name           = data.azurerm_resource_group.main.name
  storage_resource_group        = data.azurerm_resource_group.ignition_storage.name
  storage_account_name          = var.azure_ignition_storage_account_name
  availability_zones            = var.azure_master_availability_zones
  node_count                    = var.worker_count
  infra_count                   = var.infra_count
  azure_region                  = var.azure_region
  worker_vm_type                = var.azure_worker_vm_type
  infra_vm_type                 = var.azure_infra_vm_type
  master_vm_type                = var.azure_master_vm_type
  worker_os_disk_size           = var.azure_worker_root_volume_size
  infra_os_disk_size            = var.azure_infra_root_volume_size
  master_os_disk_size           = var.azure_master_root_volume_size
  azure_subscription_id         = local.azure_subscription_id
  azure_client_id               = local.azure_client_id
  azure_client_secret           = local.azure_client_secret
  azure_tenant_id               = local.azure_tenant_id
  azure_rhcos_image_id          = local.azure_image_id
  virtual_network_name          = local.azure_virtual_network
  network_resource_group_name   = local.azure_network_resource_group_name
  control_plane_subnet          = local.azure_control_plane_subnet
  compute_subnet                = local.azure_compute_subnet
  private                       = module.vnet.private
  outbound_udr                  = var.azure_outbound_user_defined_routing
  airgapped                     = var.airgapped
  proxy_config                  = var.proxy_config
  trust_bundle                  = var.openshift_additional_trust_bundle
  trust_bundle_string           = var.openshift_additional_trust_bundle_string
  byo_dns                       = var.openshift_byo_dns
  openshift_dns_provider        = var.openshift_dns_provider
  managed_infrastructure        = var.openshift_managed_infrastructure
  use_default_imageregistry     = var.use_default_imageregistry
  ignition_sas_token            = var.azure_ignition_sas_token
  ignition_sas_container_name   = var.azure_ignition_sas_container_name
  proxy_eval                    = var.no_proxy_test 
}

module "bootstrap" {
  count                     = !var.bootstrap_cleanup ? 1 : 0
  
  source                    = "./bootstrap"
  resource_group_name       = data.azurerm_resource_group.main.name
  region                    = var.azure_region
  vm_size                   = var.azure_bootstrap_vm_type
  vm_image                  = local.azure_image_id
  azure_shared_image        = var.azure_shared_image
  identity                  = var.openshift_managed_infrastructure ? azurerm_user_assigned_identity.main[0].id : ""
  cluster_id                = local.cluster_id
  ignition                  = module.ignition.bootstrap_ignition
  subnet_id                 = module.vnet.master_subnet_id
  elb_backend_pool_v4_id    = module.vnet.public_lb_backend_pool_v4_id
  elb_backend_pool_v6_id    = module.vnet.public_lb_backend_pool_v6_id
  ilb_backend_pool_v4_id    = module.vnet.internal_lb_backend_pool_v4_id
  ilb_backend_pool_v6_id    = module.vnet.internal_lb_backend_pool_v6_id
  tags                      = local.tags
  bootlogs_uri              = local.azure_bootlogs_storage_account_uri
  nsg_name                  = module.vnet.cluster_nsg_name
  private                   = module.vnet.private
  outbound_udr              = var.azure_outbound_user_defined_routing

  use_ipv4                  = var.use_ipv4 || var.azure_emulate_single_stack_ipv6
  use_ipv6                  = var.use_ipv6
  emulate_single_stack_ipv6 = var.azure_emulate_single_stack_ipv6

  phased_approach           = var.phased_approach 
  phase1_complete           = var.phase1_complete
  managed_infrastructure    = var.openshift_managed_infrastructure
}

module "master" {
  source                 = "./master"
  resource_group_name    = data.azurerm_resource_group.main.name
  cluster_id             = local.cluster_id
  region                 = var.azure_region
  availability_zones     = var.azure_master_availability_zones
  vm_size                = var.azure_master_vm_type
  vm_image               = local.azure_image_id
  azure_shared_image     = var.azure_shared_image
  identity               = var.openshift_managed_infrastructure ? azurerm_user_assigned_identity.main[0].id : ""
  ignition               = module.ignition.master_ignition
  elb_backend_pool_v4_id = module.vnet.public_lb_backend_pool_v4_id
  elb_backend_pool_v6_id = module.vnet.public_lb_backend_pool_v6_id
  ilb_backend_pool_v4_id = module.vnet.internal_lb_backend_pool_v4_id
  ilb_backend_pool_v6_id = module.vnet.internal_lb_backend_pool_v6_id
  subnet_id              = module.vnet.master_subnet_id
  instance_count         = var.master_count
  bootlogs_uri           = local.azure_bootlogs_storage_account_uri
  os_volume_type         = var.azure_master_root_volume_type
  os_volume_size         = var.azure_master_root_volume_size
  private                = module.vnet.private
  outbound_udr           = var.azure_outbound_user_defined_routing

  use_ipv4                  = var.use_ipv4 || var.azure_emulate_single_stack_ipv6
  use_ipv6                  = var.use_ipv6
  emulate_single_stack_ipv6 = var.azure_emulate_single_stack_ipv6

  phased_approach           = var.phased_approach 
  phase1_complete           = var.phase1_complete
  managed_infrastructure    = var.openshift_managed_infrastructure

  depends_on = [module.bootstrap]
}

module "infra" {
  count                  = !var.openshift_managed_infrastructure ? 1 : 0

  source                 = "./worker"
  node_role              = "infra"
  resource_group_name    = data.azurerm_resource_group.main.name
  cluster_id             = local.cluster_id
  region                 = var.azure_region
  availability_zones     = var.azure_master_availability_zones
  vm_size                = var.azure_infra_vm_type
  vm_image               = local.azure_image_id
  azure_shared_image     = var.azure_shared_image
  identity               = var.openshift_managed_infrastructure ? azurerm_user_assigned_identity.main[0].id : ""
  ignition               = module.ignition.worker_ignition
  elb_backend_pool_v4_id = module.vnet.public_lb_backend_pool_v4_id
  elb_backend_pool_v6_id = module.vnet.public_lb_backend_pool_v6_id
  ilb_backend_pool_v4_id = module.vnet.internal_lb_apps_backend_pool_v4_id
  ilb_backend_pool_v6_id = module.vnet.internal_lb_apps_backend_pool_v6_id
  subnet_id              = module.vnet.worker_subnet_id
  instance_count         = var.infra_count
  bootlogs_uri           = local.azure_bootlogs_storage_account_uri
  os_volume_type         = var.azure_worker_root_volume_type
  os_volume_size         = var.azure_infra_root_volume_size
  private                = module.vnet.private
  outbound_udr           = var.azure_outbound_user_defined_routing

  use_ipv4                  = var.use_ipv4 || var.azure_emulate_single_stack_ipv6
  use_ipv6                  = var.use_ipv6
  emulate_single_stack_ipv6 = var.azure_emulate_single_stack_ipv6

  phased_approach           = var.phased_approach 
  phase1_complete           = var.phase1_complete
  managed_infrastructure    = var.openshift_managed_infrastructure
  infra_data_disk_size_GB   = var.infra_data_disk_size_GB
  number_of_disks_per_node  = var.infra_number_of_disks_per_node

  depends_on = [module.master]
}

module "worker" {
  count                  = !var.openshift_managed_infrastructure ? 1 : 0

  source                 = "./worker"
  node_role              = "worker"
  resource_group_name    = data.azurerm_resource_group.main.name
  cluster_id             = local.cluster_id
  region                 = var.azure_region
  availability_zones     = var.azure_master_availability_zones
  vm_size                = var.azure_worker_vm_type
  vm_image               = local.azure_image_id
  azure_shared_image     = var.azure_shared_image
  identity               = var.openshift_managed_infrastructure ? azurerm_user_assigned_identity.main[0].id : ""
  ignition               = module.ignition.worker_ignition
  elb_backend_pool_v4_id = module.vnet.public_lb_backend_pool_v4_id
  elb_backend_pool_v6_id = module.vnet.public_lb_backend_pool_v6_id
  ilb_backend_pool_v4_id = module.vnet.internal_lb_apps_backend_pool_v4_id
  ilb_backend_pool_v6_id = module.vnet.internal_lb_apps_backend_pool_v6_id
  subnet_id              = module.vnet.worker_subnet_id
  instance_count         = var.worker_count
  bootlogs_uri           = local.azure_bootlogs_storage_account_uri
  os_volume_type         = var.azure_worker_root_volume_type
  os_volume_size         = var.azure_worker_root_volume_size
  private                = module.vnet.private
  outbound_udr           = var.azure_outbound_user_defined_routing

  use_ipv4                  = var.use_ipv4 || var.azure_emulate_single_stack_ipv6
  use_ipv6                  = var.use_ipv6
  emulate_single_stack_ipv6 = var.azure_emulate_single_stack_ipv6

  phased_approach           = var.phased_approach 
  phase1_complete           = var.phase1_complete
  managed_infrastructure    = var.openshift_managed_infrastructure
  worker_data_disk_size_GB  = var.worker_data_disk_size_GB

  depends_on = [module.master]
}

resource "azurerm_resource_group" "main" {
  count = var.azure_resource_group_name == "" ? 1 : 0

  name     = "${local.cluster_id}-rg"
  location = var.azure_region
  tags     = local.tags
}

data "azurerm_resource_group" "main" {
  name = var.azure_resource_group_name != "" ? var.azure_resource_group_name : azurerm_resource_group.main[0].name
}

data "azurerm_resource_group" "network" {
  count = var.azure_preexisting_network ? 1 : 0

  name = local.azure_network_resource_group_name
}

data "azurerm_resource_group" "image_storage" {
  name = var.azure_image_storage_rg != "" ? var.azure_image_storage_rg : data.azurerm_resource_group.main.name
}

data "azurerm_resource_group" "ignition_storage" {
  name = var.azure_ignition_storage_rg != "" ? var.azure_ignition_storage_rg : data.azurerm_resource_group.main.name
}

data "azurerm_resource_group" "bootlogs_storage" {
  name = var.azure_bootlogs_storage_rg != "" ? var.azure_bootlogs_storage_rg : data.azurerm_resource_group.main.name
}

resource "azurerm_storage_account" "bootlogs" {
  count = var.use_bootlogs_storage_account && var.azure_bootlogs_storage_account_name == "" ? 1 : 0

  name                     = "bootlogs${var.cluster_name}${random_string.cluster_id.result}"
  resource_group_name      = data.azurerm_resource_group.bootlogs_storage.name
  location                 = var.azure_region
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

data "azurerm_storage_account" "bootlogs" {
  count = var.use_bootlogs_storage_account && var.azure_bootlogs_sas_token == "" ? 1 : 0

  name                     = var.azure_bootlogs_storage_account_name != "" ? var.azure_bootlogs_storage_account_name : azurerm_storage_account.bootlogs[0].name
  resource_group_name      = data.azurerm_resource_group.bootlogs_storage.name
}

resource "azurerm_user_assigned_identity" "main" {
  count = var.openshift_managed_infrastructure ? 1 : 0

  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location

  name = "${local.cluster_id}-identity"
}

data "azurerm_role_definition" "contributor" {
  name = "Contributor"
}

resource "azurerm_role_assignment" "main" {
  count = var.openshift_managed_infrastructure ? 1 : 0

  scope                = data.azurerm_resource_group.main.id
  role_definition_id = (var.azure_role_id_cluster == "") ? data.azurerm_role_definition.contributor.id : var.azure_role_id_cluster
  principal_id         = azurerm_user_assigned_identity.main[0].principal_id
}

resource "azurerm_role_assignment" "network" {
  count = var.openshift_managed_infrastructure && var.azure_preexisting_network ? 1 : 0

  scope                = data.azurerm_resource_group.network[0].id
  role_definition_id = (var.azure_role_id_network == "") ? data.azurerm_role_definition.contributor.id : var.azure_role_id_network
  principal_id         = azurerm_user_assigned_identity.main[0].principal_id
}
