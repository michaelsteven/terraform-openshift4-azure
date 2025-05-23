output "public_lb_backend_pool_v4_id" {
  value = local.need_public_ipv4 ? azurerm_lb_backend_address_pool.public_lb_pool_v4[0].id : null
}

output "public_lb_backend_pool_v6_id" {
  value = local.need_public_ipv6 ? azurerm_lb_backend_address_pool.public_lb_pool_v6[0].id : null
}

output "internal_lb_apps_backend_pool_v4_id" {
  value = var.use_ipv4 ? azurerm_lb_backend_address_pool.internal_lb_worker_pool_v4[0].id : null
}

output "internal_lb_apps_backend_pool_v6_id" {
  value = var.use_ipv6 ? azurerm_lb_backend_address_pool.internal_lb_worker_pool_v6[0].id : null
}

output "internal_lb_backend_pool_v4_id" {
  value = var.use_ipv4 ? azurerm_lb_backend_address_pool.internal_lb_controlplane_pool_v4[0].id : null
}

output "internal_lb_backend_pool_v6_id" {
  value = var.use_ipv6 ? azurerm_lb_backend_address_pool.internal_lb_controlplane_pool_v6[0].id : null
}

output "public_lb_id" {
  value = var.private ? null : azurerm_lb.public[0].id
}

output "public_lb_pip_v4_fqdn" {
  value = local.need_public_ipv4 ? data.azurerm_public_ip.cluster_public_ip_v4[0].fqdn : null
}

output "public_lb_pip_v6_fqdn" {
  value = local.need_public_ipv6 ? data.azurerm_public_ip.cluster_public_ip_v6[0].fqdn : null
}

output "public_lb_ip_v4_address" {
  value = local.need_public_ipv4 ? data.azurerm_public_ip.cluster_public_ip_v4[0].ip_address : null
}

output "public_lb_ip_v6_address" {
  value = local.need_public_ipv6 ? data.azurerm_public_ip.cluster_public_ip_v6[0].ip_address : null
}

output "internal_lb_ip_v4_address" {
  value = var.use_ipv4 ? azurerm_lb.internal.private_ip_addresses[0] : null
}

output "internal_lb_ip_v6_address" {
  // TODO: internal LB should block v4 for better single stack emulation (&& ! var.emulate_single_stack_ipv6)
  //   but RHCoS initramfs can't do v6 and so fails to ignite. https://issues.redhat.com/browse/GRPA-1343 
  value = var.use_ipv6 ? ( var.use_ipv4 ? azurerm_lb.internal.private_ip_addresses[1] : azurerm_lb.internal.private_ip_addresses[0] ) : null
}

output "internal_lb_apps_ip_v4_address" {
  value = var.use_ipv4 ? ( var.use_ipv6 ? azurerm_lb.internal.private_ip_addresses[2] : azurerm_lb.internal.private_ip_addresses[1] ) : null
}

output "internal_lb_apps_ip_v6_address" {
  // TODO: internal LB should block v4 for better single stack emulation (&& ! var.emulate_single_stack_ipv6)
  //   but RHCoS initramfs can't do v6 and so fails to ignite. https://issues.redhat.com/browse/GRPA-1343 
  value = var.use_ipv6 ? ( var.use_ipv4 ? azurerm_lb.internal.private_ip_addresses[3] : azurerm_lb.internal.private_ip_addresses[1] ) : null
}

output "cluster_nsg_name" {
  value = local.nsg_name
}

output "virtual_network_id" {
  value = local.virtual_network_id
}

output "master_subnet_id" {
  value = local.master_subnet_id
}

output "worker_subnet_id" {
  value = local.worker_subnet_id
}

output "private" {
  value = var.private
}
