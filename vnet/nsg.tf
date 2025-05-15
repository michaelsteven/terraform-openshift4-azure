locals {
  nsg_id = var.preexisting_network ? null : azurerm_network_security_group.cluster[0].id
  nsg_name = "${var.cluster_id}-nsg"
}


resource "azurerm_network_security_group" "cluster" {
  count               = var.preexisting_network ? 0 : 1
  name                = "${var.cluster_id}-nsg"
  location            = var.region
  resource_group_name = var.resource_group_name
}

resource "azurerm_subnet_network_security_group_association" "master" {
  count = var.preexisting_network ? 0 : 1

  subnet_id                 = azurerm_subnet.master_subnet[0].id
  network_security_group_id = local.nsg_id
  depends_on                = [azurerm_network_security_group.cluster]
}

resource "azurerm_subnet_network_security_group_association" "worker" {
  count = var.preexisting_network ? 0 : 1

  subnet_id                 = azurerm_subnet.worker_subnet[0].id
  network_security_group_id = local.nsg_id
  depends_on                = [azurerm_network_security_group.cluster]
}

resource "azurerm_network_security_rule" "apiserver_in" {
  count                       = var.preexisting_network ? 0 : 1
  name                        = "apiserver_in"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "6443"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.resource_group_name
  network_security_group_name = local.nsg_name
    depends_on                = [azurerm_network_security_group.cluster]
}

resource "azurerm_network_security_rule" "ssh_in" {
  count                       = var.preexisting_network ? 0 : 1
  name                        = "ssh_in"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.resource_group_name
  network_security_group_name = local.nsg_name
  depends_on                  = [azurerm_network_security_group.cluster]
}

resource "azurerm_network_security_rule" "tcp-http" {
  count                       = var.preexisting_network ? 0 : 1
  name                        = "tcp-80"
  priority                    = 201
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.resource_group_name
  network_security_group_name = local.nsg_name
  depends_on                  = [azurerm_network_security_group.cluster]
}

resource "azurerm_network_security_rule" "tcp-https" {
  count                       = var.preexisting_network ? 0 : 1
  name                        = "tcp-443"
  priority                    = 202
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.resource_group_name
  network_security_group_name = local.nsg_name
  depends_on                  = [azurerm_network_security_group.cluster]
}