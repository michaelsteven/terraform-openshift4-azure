variable "vhd_exists" {
  description = "Does the blob already exist in an existing Storage account"
  type        = bool
  default     = false
}

variable "storage_account_exists" {
  description = "Define if existing storage account to be used"
  type        = bool
  default     = false
}

variable "storage_account_sas" {
  description = "Define if a SAS storage account is to be used"
  type        = bool
  default     = false
}

variable "storage_blob_sas_uri" {
  description = "The vhd image full sas uri if the image already exists"
  type        = string
  default     = ""
}

variable "openshift_version" {
  type    = string
  default = "latest"
}

variable "sas_token_vhd" {
  description = "The SAS storage token string for the vhd file"
  type        = string
  default     = ""
}

variable "storage_account_name" {
  type    = string
  default = ""
}

variable "storage_blob_name" {
  description = "azure blob which is the coreos vhd file"
  type        = string
  default     = ""
}

variable "container_name_vhd" {
  description = "Name of the container used for SAS storage for the vhd file"
  type        = string
  default     = ""
}

variable "installer_workspace" {
  description = "Local directory used for storing installation workspace files"
  type        = string
  default     = ""
}

variable "cluster_unique_string" {
  description = "Random generated unique cluster string"
  type        = string
  default     = ""
}

variable "cluster_id" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "azure_region" {
  type = string
}
