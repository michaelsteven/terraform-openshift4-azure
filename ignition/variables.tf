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

variable "byo_dns" {
  type    = bool
  default = false
}

variable "storage_account_name" {
  type    = string
  default = ""
}

variable "storage_resource_group" {
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

variable "ignition_sas_token" {
  description = "The SAS storage token string for the ignition files"
  type        = string
  default     = ""
}

variable "ignition_sas_container_name" {
  description = "Name of the container used for SAS storage for the ignition files"
  type        = string
  default     = ""
}

variable "openshift_pull_secret_string" {
  type        = string
  description = "pull-secret as a string"
  default     = ""
}