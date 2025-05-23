locals {
  # extracting "api.<clustername>" from <clusterdomain>
  api_external_name = "api.${replace(var.cluster_domain, ".${var.base_domain}", "")}"
}

resource "azurerm_private_dns_zone" "private" {
  name                = var.cluster_domain
  resource_group_name = var.resource_group_name

  depends_on = [azurerm_dns_cname_record.api_external_v4, azurerm_dns_cname_record.api_external_v6]
}

resource "azurerm_private_dns_zone_virtual_network_link" "network" {
  name                  = "${var.cluster_id}-network-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.private.name
  virtual_network_id    = var.virtual_network_id
}

resource "azurerm_private_dns_a_record" "apiint_internal" {
  # TODO: internal LB should block v4 for better single stack emulation (&& ! var.emulate_single_stack_ipv6)
  #   but RHCoS initramfs can't do v6 and so fails to ignite. https://issues.redhat.com/browse/GRPA-1343 
  count = var.use_ipv4 ? 1 : 0

  name                = "api-int"
  zone_name           = azurerm_private_dns_zone.private.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [var.internal_lb_ipaddress_v4]
}

resource "azurerm_private_dns_aaaa_record" "apiint_internal_v6" {
  count = var.use_ipv6 ? 1 : 0

  name                = "api-int"
  zone_name           = azurerm_private_dns_zone.private.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [var.internal_lb_ipaddress_v6]
}

resource "azurerm_private_dns_a_record" "api_internal" {
  # TODO: internal LB should block v4 for better single stack emulation (&& ! var.emulate_single_stack_ipv6)
  #   but RHCoS initramfs can't do v6 and so fails to ignite. https://issues.redhat.com/browse/GRPA-1343 
  count = var.use_ipv4 ? 1 : 0

  name                = "api"
  zone_name           = azurerm_private_dns_zone.private.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [var.internal_lb_ipaddress_v4]
}

resource "azurerm_private_dns_aaaa_record" "api_internal_v6" {
  count = var.use_ipv6 ? 1 : 0

  name                = "api"
  zone_name           = azurerm_private_dns_zone.private.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [var.internal_lb_ipaddress_v6]
}

resource "azurerm_dns_cname_record" "api_external_v4" {
  count = var.private || !var.use_ipv4 ? 0 : 1

  name                = local.api_external_name
  zone_name           = var.base_domain
  resource_group_name = var.base_domain_resource_group_name
  ttl                 = 300
  record              = var.external_lb_fqdn_v4
}

resource "azurerm_dns_cname_record" "api_external_v6" {
  count = var.private || !var.use_ipv6 ? 0 : 1

  name                = "v6-${local.api_external_name}"
  zone_name           = var.base_domain
  resource_group_name = var.base_domain_resource_group_name
  ttl                 = 300
  record              = var.external_lb_fqdn_v6
}

resource "azurerm_private_dns_a_record" "apps_internal" {
  count = var.use_ipv4 ? 1 : 0

  name                = "*.apps"
  zone_name           = azurerm_private_dns_zone.private.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [var.internal_lb_apps_ipaddress_v4]
}

resource "azurerm_private_dns_aaaa_record" "apps_internal_v6" {
  count = var.use_ipv6 ? 1 : 0

  name                = "*.apps"
  zone_name           = azurerm_private_dns_zone.private.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [var.internal_lb_apps_ipaddress_v6]
}

resource "azurerm_private_dns_zone" "storage_private_link" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "network_link_storage" {
  name                  = "${var.cluster_id}-storage-network-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.storage_private_link.name
  virtual_network_id    = var.virtual_network_id
}

resource "azurerm_private_dns_a_record" "ignition_private_link" {
  name                = var.ignition_storage_account_name
  zone_name           = azurerm_private_dns_zone.storage_private_link.name
  resource_group_name = var.resource_group_name
  ttl                 = 10
  records             = [var.ignition_storage_private_endpoint_ip_address]
}