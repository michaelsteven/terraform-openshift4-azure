locals {
  // The name of the workers' ipconfiguration is hardcoded to "pipconfig". It needs to match cluster-api
  // https://github.com/openshift/cluster-api-provider-azure/blob/worker/pkg/cloud/azure/services/networkinterfaces/networkinterfaces.go#L131
  ip_v4_configuration_name = "pipConfig"
  // TODO: Azure machine provider probably needs to look for pipConfig-v6 as well (or a different name like pipConfig-secondary)
  ip_v6_configuration_name = "pipConfig-v6"
  identity_list = var.managed_infrastructure ? [var.identity] : []
  bootlogs_base_uri                      = "https://${var.bootlogs_storage_account_name}.blob.core.windows.net/"
}

resource "azurerm_network_interface" "worker" {
  count = var.instance_count

  name                = "${var.cluster_id}-${var.node_role}${count.index}-nic"
  location            = var.region
  resource_group_name = var.resource_group_name

  dynamic "ip_configuration" {
    for_each = [for ip in [
      {
        // LIMITATION: azure does not allow an ipv6 address to be primary today
        primary : var.use_ipv4,
        name : local.ip_v4_configuration_name,
        ip_address_version : "IPv4",
        include : var.use_ipv4 || var.use_ipv6
      },
      {
        primary : ! var.use_ipv4,
        name : local.ip_v6_configuration_name,
        ip_address_version : "IPv6",
        include : var.use_ipv6
      },
      ] : {
      primary : ip.primary
      name : ip.name
      ip_address_version : ip.ip_address_version
      include : ip.include
      } if ip.include
    ]
    content {
      primary                       = ip_configuration.value.primary
      name                          = ip_configuration.value.name
      subnet_id                     = var.subnet_id
      private_ip_address_version    = ip_configuration.value.ip_address_version
      private_ip_address_allocation = "Dynamic"
    }
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "worker_v4" {
  // This is required because terraform cannot calculate counts during plan phase completely and therefore the `vnet/public-lb.tf`
  // conditional need to be recreated. See https://github.com/hashicorp/terraform/issues/12570
  count = (! var.private || ! var.outbound_udr) ? var.instance_count : 0

  network_interface_id    = element(azurerm_network_interface.worker.*.id, count.index)
  backend_address_pool_id = var.elb_backend_pool_v4_id
  ip_configuration_name   = local.ip_v4_configuration_name
}

resource "azurerm_network_interface_backend_address_pool_association" "worker_v6" {
  // This is required because terraform cannot calculate counts during plan phase completely and therefore the `vnet/public-lb.tf`
  // conditional need to be recreated. See https://github.com/hashicorp/terraform/issues/12570
  count = var.use_ipv6 && (! var.private || ! var.outbound_udr) ? var.instance_count : 0

  network_interface_id    = element(azurerm_network_interface.worker.*.id, count.index)
  backend_address_pool_id = var.elb_backend_pool_v6_id
  ip_configuration_name   = local.ip_v6_configuration_name
}

resource "azurerm_network_interface_backend_address_pool_association" "worker_internal_v4" {
  count = var.use_ipv4 ? var.instance_count : 0

  network_interface_id    = element(azurerm_network_interface.worker.*.id, count.index)
  backend_address_pool_id = var.ilb_backend_pool_v4_id
  ip_configuration_name   = local.ip_v4_configuration_name
}

resource "azurerm_network_interface_backend_address_pool_association" "worker_internal_v6" {
  count = var.use_ipv6 ? var.instance_count : 0

  network_interface_id    = element(azurerm_network_interface.worker.*.id, count.index)
  backend_address_pool_id = var.ilb_backend_pool_v6_id
  ip_configuration_name   = local.ip_v6_configuration_name
}

resource "azurerm_linux_virtual_machine" "worker" {
  count = !var.phased_approach || (var.phased_approach && var.phase1_complete) ? var.instance_count : 0 

  depends_on = [
    azurerm_network_interface.worker
  ]
  
  name                  = "${var.cluster_id}-${var.node_role}-${count.index}"
  location              = var.region
  zone                  = length(var.availability_zones) > 1 ? var.availability_zones[count.index % length(var.availability_zones)] : var.availability_zones[0]
  resource_group_name   = var.resource_group_name
  network_interface_ids = [element(azurerm_network_interface.worker.*.id, count.index)]
  size                  = var.vm_size
  admin_username        = "core"
  # The password is normally applied by WALA (the Azure agent), but this
  # isn't installed in RHCOS. As a result, this password is never set. It is
  # included here because it is required by the Azure ARM API.
  admin_password                  = "NotActuallyApplied!"
  disable_password_authentication = false

  dynamic "identity" {
    for_each = local.identity_list
    content {
      type         = "UserAssigned"
      identity_ids = local.identity_list
    }
  }

  os_disk {
    name                 = "${var.cluster_id}-${var.node_role}-${count.index}_OSDisk" # os disk name needs to match cluster-api convention
    caching              = "ReadOnly"
    storage_account_type = var.os_volume_type
    disk_size_gb         = var.os_volume_size
  }

  source_image_id = var.vm_image

  //we don't provide a ssh key, because it is set with ignition. 
  //it is required to provide at least 1 auth method to deploy a linux vm
  computer_name = "${var.cluster_id}-${var.node_role}-${count.index}"
  custom_data   = base64encode(var.ignition)

  boot_diagnostics {
    storage_account_uri = var.bootlogs_sas_token != "" ? "${local.bootlogs_base_uri}?${var.bootlogs_sas_token}" : var.bootlogs_storage_account[0].primary_blob_endpoint
  }
}

resource "azurerm_managed_disk" "storage" {
  count = var.infra_data_disk_size_GB>0 ? var.instance_count : 0

  name                 = "${var.cluster_id}-infra-${count.index}-data-disk"
  location             = var.region
  resource_group_name  = var.resource_group_name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.infra_data_disk_size_GB
  zones                = [length(var.availability_zones) > 1 ? var.availability_zones[count.index % length(var.availability_zones)] : var.availability_zones[0]]
  
}

resource "azurerm_virtual_machine_data_disk_attachment" "data_disk" {
  count = var.infra_data_disk_size_GB>0 ? var.instance_count : 0

  managed_disk_id    = azurerm_managed_disk.storage[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.worker[count.index].id
  lun                = "10"
  caching            = "ReadWrite"
}
