output "ignition_storage_account_id" {
    value = azurerm_storage_account.ignition.id
}

output "ignition_storage_account_name" {
    value = azurerm_storage_account.ignition.name
}

output "ignition_storage_container_name" {
    value = azurerm_storage_container.ignition.name
}

output "ignition_storage_private_endpoint_ip_address" {
    value = azurerm_private_endpoint.storage_private_endpoint.private_service_connection[0].private_ip_address
}

output "ignition_storage_account_sas" {
    value = data.azurerm_storage_account_sas.ignition.sas
}