variable "base_domain" {
  type = string
}

variable "master_count" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "cluster_unique_string" {
  description = "Random generated unique cluster string"
  type        = string
  default     = ""
}

variable "cluster_network_cidr" {
  type = string
}

variable "cluster_network_host_prefix" {
  type = string
}

variable "machine_cidr" {
  type = string
}

variable "service_network_cidr" {
  type = string
}

variable "azure_dns_resource_group_name" {
  type = string
}

variable "openshift_pull_secret" {
  type = string
}

variable "public_ssh_key" {
  type = string
}

variable "openshift_installer_url" {
  type    = string
  default = "https://mirror.openshift.com/pub/openshift-v4/clients/ocp"
}

variable "openshift_version" {
  type    = string
  default = "latest"
}

variable "cluster_id" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "availability_zones" {
  type = list(string)
}

variable "node_count" {
  type = string
}

variable "infra_count" {
  type = string
}

variable "azure_region" {
  type = string
}

variable "master_vm_type" {
  type = string
}

variable "infra_vm_type" {
  type = string
}

variable "worker_vm_type" {
  type = string
}

variable "worker_os_disk_size" {
  type    = string
  default = 512
}

variable "infra_os_disk_size" {
  type    = string
  default = 512
}

variable "master_os_disk_size" {
  type    = string
  default = 512
}

variable "azure_subscription_id" {
  type = string
}

variable "azure_client_id" {
  type = string
}

variable "azure_client_secret" {
  type = string
}

variable "azure_tenant_id" {
  type = string
}

variable "azure_rhcos_image_id" {
  type = string
}

variable "virtual_network_name" {
  type = string
}

variable "network_resource_group_name" {
  type = string
}

variable "control_plane_subnet" {
  type = string
}

variable "compute_subnet" {
  type = string
}

variable "private" {
  type = bool
}

variable "outbound_udr" {
  type = bool
}

variable "airgapped" {
  type = map(string)
  default = {
    airgapped  = false
    repository = ""
  }
}

variable "proxy_config" {
  type = map(string)
  default = {
    enabled    = false
    httpProxy  = ""
    httpsProxy = ""
    noProxy    = ""
  }
}

variable "trust_bundle" {
  type    = string
  default = ""
}

variable "trust_bundle_string" {
  type    = string
  default = ""
}

variable "byo_dns" {
  type    = bool
  default = false
}

variable "openshift_dns_provider" {
  type        = string
  default     = "azure"
}

variable "storage_account_name" {
  type    = string
  default = ""
}

variable "storage_account_sas" {
  type    = string
  default = ""
}

variable "storage_container_name" {
  type    = string
  default = ""
}

variable "apps_ip" {
  type    = string
  default = ""
}

variable "managed_infrastructure" {
  description = "Define if nodes are managed by openshift"
  type        = bool
  default     = true  
}

variable "use_default_imageregistry" {
  description = "Define if default imageregistry is required"
  type        = bool
  default     = true
}

variable "openshift_pull_secret_string" {
  type        = string
  description = "pull-secret as a string"
  default     = ""
}

variable "proxy_eval" {
  type        = bool
  description = "Turn on/off proxy evaluation for testing"
  default     = false  
}

variable "master_subnet_id" {
  type        = string
  description = "ID of the master subnet"
}


variable "worker_subnet_id" {
  type        = string
  description = "ID of the worker subnet"
}


variable "resource_prefix" {
  type        = string
  description = "the prefix to prepend to created resources"
}

variable "disk_encryption_set_name" {
  type        = string
  description = "Disk encryption set to use for machine disks"
}