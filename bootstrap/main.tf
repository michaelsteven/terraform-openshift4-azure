locals {
  bootstrap_nic_ip_v4_configuration_name = "bootstrap-nic-ip-v4"
  bootstrap_nic_ip_v6_configuration_name = "bootstrap-nic-ip-v6"
  identity_list                          = var.managed_infrastructure ? [var.identity] : []
}

resource "azurerm_public_ip" "bootstrap_public_ip_v4" {
  count = var.private || ! var.use_ipv4 ? 0 : 1

  sku                 = "Standard"
  location            = var.region
  name                = "${var.cluster_id}-bootstrap-pip-v4"
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
}

data "azurerm_public_ip" "bootstrap_public_ip_v4" {
  count = var.private ? 0 : 1

  name                = azurerm_public_ip.bootstrap_public_ip_v4[0].name
  resource_group_name = var.resource_group_name
}

resource "azurerm_public_ip" "bootstrap_public_ip_v6" {
  count = var.private || ! var.use_ipv6 ? 0 : 1

  sku                 = "Standard"
  location            = var.region
  name                = "${var.cluster_id}-bootstrap-pip-v6"
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  ip_version          = "IPv6"
}

data "azurerm_public_ip" "bootstrap_public_ip_v6" {
  count = var.private || ! var.use_ipv6 ? 0 : 1

  name                = azurerm_public_ip.bootstrap_public_ip_v6[0].name
  resource_group_name = var.resource_group_name
}

resource "azurerm_network_interface" "bootstrap" {
  name                = "${var.cluster_id}-bootstrap-nic"
  location            = var.region
  resource_group_name = var.resource_group_name

  dynamic "ip_configuration" {
    for_each = [for ip in [
      {
        // LIMITATION: azure does not allow an ipv6 address to be primary today
        primary : var.use_ipv4,
        name : local.bootstrap_nic_ip_v4_configuration_name,
        ip_address_version : "IPv4",
        public_ip_id : var.private ? null : azurerm_public_ip.bootstrap_public_ip_v4[0].id,
        include : var.use_ipv4 || var.use_ipv6,
      },
      {
        primary : ! var.use_ipv4,
        name : local.bootstrap_nic_ip_v6_configuration_name,
        ip_address_version : "IPv6",
        public_ip_id : var.private || ! var.use_ipv6 ? null : azurerm_public_ip.bootstrap_public_ip_v6[0].id,
        include : var.use_ipv6,
      },
      ] : {
      primary : ip.primary
      name : ip.name
      ip_address_version : ip.ip_address_version
      public_ip_id : ip.public_ip_id
      include : ip.include
      } if ip.include
    ]
    content {
      primary                       = ip_configuration.value.primary
      name                          = ip_configuration.value.name
      subnet_id                     = var.subnet_id
      private_ip_address_version    = ip_configuration.value.ip_address_version
      private_ip_address_allocation = "Dynamic"
      public_ip_address_id          = ip_configuration.value.public_ip_id
    }
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "public_lb_bootstrap_v4" {
  // This is required because terraform cannot calculate counts during plan phase completely and therefore the `vnet/public-lb.tf`
  // conditional need to be recreated. See https://github.com/hashicorp/terraform/issues/12570
  count = (! var.private || ! var.outbound_udr) ? 1 : 0

  network_interface_id    = azurerm_network_interface.bootstrap.id
  backend_address_pool_id = var.elb_backend_pool_v4_id
  ip_configuration_name   = local.bootstrap_nic_ip_v4_configuration_name
}

resource "azurerm_network_interface_backend_address_pool_association" "public_lb_bootstrap_v6" {
  // This is required because terraform cannot calculate counts during plan phase completely and therefore the `vnet/public-lb.tf`
  // conditional need to be recreated. See https://github.com/hashicorp/terraform/issues/12570
  count = var.use_ipv6 && (! var.private || ! var.outbound_udr) ? 1 : 0

  network_interface_id    = azurerm_network_interface.bootstrap.id
  backend_address_pool_id = var.elb_backend_pool_v6_id
  ip_configuration_name   = local.bootstrap_nic_ip_v6_configuration_name
}

resource "azurerm_network_interface_backend_address_pool_association" "internal_lb_bootstrap_v4" {
  count = var.use_ipv4 ? 1 : 0

  network_interface_id    = azurerm_network_interface.bootstrap.id
  backend_address_pool_id = var.ilb_backend_pool_v4_id
  ip_configuration_name   = local.bootstrap_nic_ip_v4_configuration_name
}

resource "azurerm_network_interface_backend_address_pool_association" "internal_lb_bootstrap_v6" {
  count = var.use_ipv6 ? 1 : 0

  network_interface_id    = azurerm_network_interface.bootstrap.id
  backend_address_pool_id = var.ilb_backend_pool_v6_id
  ip_configuration_name   = local.bootstrap_nic_ip_v6_configuration_name
}

resource "azurerm_linux_virtual_machine" "bootstrap" {
  count = !var.phased_approach || (var.phased_approach && var.phase1_complete) ? 1 : 0
  
  name                  = "${var.cluster_id}-bootstrap"
  location              = var.region
  resource_group_name   = var.resource_group_name
  network_interface_ids = [azurerm_network_interface.bootstrap.id]
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
    name                   = "${var.cluster_id}-bootstrap_OSDisk" # os disk name needs to match cluster-api convention
    caching                = "ReadWrite"
    storage_account_type   = "Premium_LRS"
    disk_size_gb           = 100
    disk_encryption_set_id = var.disk_encryption_set_id
  }

  dynamic "source_image_reference" {
      for_each = !var.azure_shared_image ? [1] : []
      content {
        publisher = "redhat"
        offer     = "rh-ocp-worker"
        sku       = "rh-ocp-worker"
        version   = "4.8.2021122100"
      }
  }

  dynamic "plan" {
      for_each = !var.azure_shared_image ? [1] : []
      content {
        name = "rh-ocp-worker"
        product = "rh-ocp-worker"
        publisher = "redhat"
      }
  }

  source_image_id = var.azure_shared_image ? var.vm_image : null

  computer_name = "${var.cluster_id}-bootstrap-vm"
  custom_data   = base64encode(var.ignition)

  lifecycle {
    ignore_changes = [custom_data]
  }
  boot_diagnostics {
    storage_account_uri = var.bootlogs_uri
  }

  depends_on = [
    azurerm_network_interface_backend_address_pool_association.public_lb_bootstrap_v4,
    azurerm_network_interface_backend_address_pool_association.public_lb_bootstrap_v6,
    azurerm_network_interface_backend_address_pool_association.internal_lb_bootstrap_v4,
    azurerm_network_interface_backend_address_pool_association.internal_lb_bootstrap_v6
  ]
}
