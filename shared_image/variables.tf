variable "openshift_version" {
  type    = string
  default = "latest"
}

variable "cluster_name" {
  description = "A unique cluster naming identifier"
  type        = string
  default     = ""
}

variable "cluster_unique_string" {
  description = "Random generated unique cluster string"
  type        = string
  default     = ""
}

variable "cluster_resource_group_name" {
  type = string
}

variable "region" {
  type = string
}

variable "shared_image_repo_name" {
  type        = string
  description = "The name of the existing repository if one is being used"
  default     = ""
}

variable "shared_image_name" {
  type        = string
  description = "The name of the existing image stored in an existing repository"
  default     = ""
}