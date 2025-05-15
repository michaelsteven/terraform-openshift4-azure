variable "resource_group_name" {
  type        = string
  description = "The resource group name for the deployment."
}

variable "cluster_id" {
  type = string
}

variable "resource_prefix" {
  type        = string
  description = "the prefix to prepend to created resources"
}

variable "cluster_name" {
  type = string
}

variable "cluster_unique_string" {
  description = "Random generated unique cluster string"
  type        = string
  default     = ""
}

variable "storage_resource_group" {
  type    = string
  default = ""
}

variable "azure_region" {
  type = string
}

variable "ignition_sas_token" {
  description = "The SAS storage token string for the ignition files"
  type        = string
  default     = ""
}

variable "private_endpoint_subnet_id" {
  type        = string
  description = "ID of the private endpoint subnet"
}