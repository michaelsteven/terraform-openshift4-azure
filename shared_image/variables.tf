variable "openshift_version" {
  type    = string
  default = "latest"
}

variable "rhcos_image" {
  type        = string
  description = "(Optional) The url to the Red Hat CoreOS image VHD file.  If blank it will attempt to construct it based on the OpenShift version."
  default     = ""
}

variable "subscription_id" {
  type        = string
  description = "The subscription that should be used to interact with Azure API"
}

variable "client_id" {
  type        = string
  description = "The app ID that should be used to interact with Azure API"
}

variable "client_secret" {
  type        = string
  description = "The password that should be used to interact with Azure API"
}

variable "tenant_id" {
  type        = string
  description = "The tenant ID that should be used to interact with Azure API"
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

variable "installer_workspace" {
  type        = string
  description = "The working directory used to hold temporary files during installation"
  default     = ""
}

variable "bash_debug" {
  type        = bool
  description = "Turn on debugging for bash scripts"
  default     = false
}

variable "proxy_eval" {
  type        = bool
  description = "Turn on/off proxy evaluation for testing"
  default     = false  
}

variable "openshift_installer_url" {
  type    = string
  default = ""
}
