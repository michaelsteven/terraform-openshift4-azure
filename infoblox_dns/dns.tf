resource "infoblox_a_record" "apiint_internal" {
  count = var.use_ipv4 ? 1 : 0

  fqdn                = "api-int.${var.cluster_name}.${var.base_domain}"
  ip_addr             = var.internal_lb_ipaddress_v4
  ttl                 = 300
}

resource "infoblox_aaaa_record" "apiint_internal_v6" {
  count = var.use_ipv6 ? 1 : 0

  fqdn                = "api-int.${var.cluster_name}.${var.base_domain}"
  ipv6_addr           = var.internal_lb_ipaddress_v6
  ttl                 = 300
}

resource "infoblox_a_record" "api_internal" {
  count = var.use_ipv4 ? 1 : 0

  fqdn                = "api.${var.cluster_name}.${var.base_domain}"
  ip_addr             = var.internal_lb_ipaddress_v4
  ttl                 = 300
}

resource "infoblox_aaaa_record" "api_internal_v6" {
  count = var.use_ipv6 ? 1 : 0

  fqdn                = "api.${var.cluster_name}.${var.base_domain}"
  ipv6_addr           = var.internal_lb_ipaddress_v6
  ttl                 = 300
}

resource "infoblox_a_record" "apps_internal_wildcard" {
  count               = var.use_ipv4 && var.infoblox_allow_any ? 1 : 0

  fqdn                = "*.apps.${var.cluster_name}.${var.base_domain}"
  ip_addr             = var.internal_lb_apps_ipaddress_v4
  ttl                 = 300
}

resource "infoblox_aaaa_record" "apps_internal_wildcard_v6" {
  count               = var.use_ipv6 && var.infoblox_allow_any ? 1 : 0

  fqdn                = "*.apps.${var.cluster_name}.${var.base_domain}"
  ipv6_addr           = var.internal_lb_apps_ipaddress_v6
  ttl                 = 300
}

resource "infoblox_a_record" "apps_internal" {
  for_each            = var.use_ipv4 && !var.infoblox_allow_any ? toset(var.infoblox_apps_dns_entries) : []

  fqdn                = "${each.value}.apps.${var.cluster_name}.${var.base_domain}"
  ip_addr             = var.internal_lb_apps_ipaddress_v4
  ttl                 = 300
}

resource "infoblox_aaaa_record" "apps_internal_v6" {
  for_each            = var.use_ipv6 && !var.infoblox_allow_any ? toset(var.infoblox_apps_dns_entries) : []

  fqdn                = "${each.value}.apps.${var.cluster_name}.${var.base_domain}"
  ipv6_addr           = var.internal_lb_apps_ipaddress_v6
  ttl                 = 300
}
