variable "region" {
  type        = string
  description = "The region for the deployment."
}

variable "resource_group_name" {
  type        = string
  description = "The resource group name for the deployment."
}

variable "cluster_id" {
  type        = string
}

variable "resource_prefix" {
  type = string
}

variable "random_string" {
  type = string
}