output "image_uri" {
  value = local.blob_uri
}

output "image_cluster_id" {
  value = azurerm_image.cluster.id
}