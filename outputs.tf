output "cluster_id" {
  value = local.cluster_id
}

output "resource_group" {
  value = data.azurerm_resource_group.main.name
}

output "image_id" {
  value = local.azure_image_id
}

output "bootstrap_public_ip" {
  value = module.bootstrap.bootstrap_public_ip
}

output "api-int-ipaddress" {
  value = var.openshift_byo_dns || var.openshift_dns_provider != "azure" ? module.vnet.internal_lb_ip_v4_address : null
}

output "api-ipaddress" {
  value = var.openshift_byo_dns || var.openshift_dns_provider != "azure" ? module.vnet.public_lb_ip_v4_address : null
}
