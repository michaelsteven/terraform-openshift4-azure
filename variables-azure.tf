variable "azure_config_version" {
  description = <<EOF
(internal) This declares the version of the Azure configuration variables.
It has no impact on generated assets but declares the version contract of the configuration.
EOF


  default = "0.1"
}

variable "azure_environment" {
  type        = string
  description = "The target Azure cloud environment for the cluster."
  default     = "public"
}

variable "azure_region" {
  type        = string
  description = "The target Azure region for the cluster."
}

variable "azure_bootstrap_vm_type" {
  type        = string
  description = "Instance type for the bootstrap node. Example: `Standard_DS4_v3`."
  default     = "Standard_D4s_v3"
}

variable "azure_master_vm_type" {
  type        = string
  description = "Instance type for the master node(s). Example: `Standard_D8s_v3`."
  default     = "Standard_D8s_v3"
}

variable "azure_extra_tags" {
  type = map(string)

  description = <<EOF
(optional) Extra Azure tags to be applied to created resources.

Example: `{ "key" = "value", "foo" = "bar" }`
EOF


  default = {}
}

variable "azure_master_root_volume_type" {
  type        = string
  description = "The type of the volume the root block device of master nodes."
  default     = "Premium_LRS"
}

variable "azure_master_root_volume_size" {
  type        = string
  description = "The size of the volume in gigabytes for the root block device of master nodes."
  default     = 512
}

variable "azure_base_domain_resource_group_name" {
  type        = string
  description = "The resource group that contains the dns zone used as base domain for the cluster."
  default     = ""
}

variable "azure_subscription_id" {
  type        = string
  description = "The subscription that should be used to interact with Azure API"
}

variable "azure_client_id" {
  type        = string
  description = "The app ID that should be used to interact with Azure API"
}

variable "azure_client_secret" {
  type        = string
  description = "The password that should be used to interact with Azure API"
}

variable "azure_tenant_id" {
  type        = string
  description = "The tenant ID that should be used to interact with Azure API"
}

variable "azure_master_availability_zones" {
  type        = list(string)
  description = "The availability zones in which to create the masters. The length of this list must match master_count."
  default = [
    "1",
    "2",
    "3",
  ]
  validation {
    condition     = length(var.azure_master_availability_zones) == 1 || length(var.azure_master_availability_zones) == 3
    error_message = "The azure_master_availability_zones variable must be set to either [1] or [1, 2, 3] zones."
  }
}

variable "azure_preexisting_network" {
  type        = bool
  default     = false
  description = "Specifies whether an existing network should be used or a new one created for installation."
}

variable "azure_resource_group_name" {
  type        = string
  default     = ""
  description = <<EOF
The name of the resource group for the cluster. If this is set, the cluster is installed to that existing resource group
otherwise a new resource group will be created using cluster id.
EOF
}

variable "azure_network_resource_group_name" {
  type        = string
  description = "The name of the network resource group, either existing or to be created."
  default     = null
}

variable "azure_virtual_network" {
  type        = string
  description = "The name of the virtual network, either existing or to be created."
  default     = null
}

variable "azure_control_plane_subnet" {
  type        = string
  description = "The name of the subnet for the control plane, either existing or to be created."
  default     = null
}

variable "azure_compute_subnet" {
  type        = string
  description = "The name of the subnet for worker nodes, either existing or to be created"
  default     = null
}

variable "azure_private" {
  type        = bool
  description = "This determines if this is a private cluster or not."
  default     = false
}

variable "azure_emulate_single_stack_ipv6" {
  type        = bool
  description = "This determines whether a dual-stack cluster is configured to emulate single-stack IPv6."
  default     = false
}

variable "azure_outbound_user_defined_routing" {
  type    = bool
  default = false

  description = <<EOF
This determined whether User defined routing will be used for egress to Internet.
When false, Standard LB will be used for egress to the Internet.
EOF
}

##############

variable "cluster_name" {
  type = string
}

variable "base_domain" {
  type = string
}

variable "machine_v4_cidrs" {
  type = list(string)
  default = [
    "10.0.0.0/16"
  ]
}

variable "machine_v6_cidrs" {
  type    = list(string)
  default = []
}

variable "openshift_cluster_network_cidr" {
  type    = string
  default = "10.128.0.0/14"
}

variable "openshift_cluster_network_host_prefix" {
  type    = string
  default = 23
}

variable "openshift_service_network_cidr" {
  type    = string
  default = "172.30.0.0/16"
}

variable "use_ipv4" {
  type    = bool
  default = true
}

variable "use_ipv6" {
  type    = bool
  default = false
}

variable "openshift_version" {
  type    = string
  default = "4.6.31"
}

variable "openshift_pull_secret" {
  type    = string
  default = "pull-secret"
}

variable "azure_infra_root_volume_size" {
  type    = string
  default = 128
}

variable "azure_worker_root_volume_size" {
  type    = string
  default = 128
}

variable "master_count" {
  type    = string
  default = 3
  validation {
    condition     = var.master_count == "3"
    error_message = "The master_count value must be set to 3."
  }
}

variable "worker_count" {
  type    = string
  default = 3
  validation {
    condition     = var.worker_count > 1
    error_message = "The worker_count value must be greater than 1."
  }
}

variable "infra_count" {
  type    = string
  default = 0
}

variable "azure_infra_vm_type" {
  type    = string
  default = "Standard_D4s_v3"
}

variable "azure_worker_vm_type" {
  type    = string
  default = "Standard_D8s_v3"
}

variable "airgapped" {
  type = map(string)
  default = {
    enabled    = false
    repository = ""
  }
}

variable "proxy_config" {
  type = map(string)
  default = {
    enabled    = false
    httpProxy  = "http://user:password@ip:port"
    httpsProxy = "http://user:password@ip:port"
    noProxy    = "ip1,ip2,ip3,.example.com,cidr/mask"
  }
}

variable "openshift_additional_trust_bundle" {
  description = "path to a file with all your additional ca certificates"
  type        = string
  default     = ""
}

variable "openshift_ssh_key" {
  description = "SSH Public Key to use for OpenShift Installation"
  type        = string
  default     = ""
}

variable "openshift_byo_dns" {
  description = "Do not deploy any public or private DNS zone into Azure"
  type        = bool
  default     = false
}

variable "api_and_api-int_dns_ip" {
  description = "The dns ip assigned to openshift api and api-int"
  type        = string
  default     = ""
}

variable "apps_dns_ip" {
  description = "The dns ip assigned to openshift api and api-int"
  type        = string
  default     = ""
}

variable "azure_image_id" {
  description = "The azure image id for the coreos vm boot image"
  type        = string
  default     = ""
}

variable "azure_image_storage_rg" {
  description = "Existing Storage Account Resource Group for the VM Image"
  type        = string
  default     = ""
}

variable "azure_image_storage_account_name" {
  description = "Existing Storage Account Name for the VM Image"
  type        = string
  default     = ""
}

variable "azure_image_blob_uri" {
  description = "The azure image blog uri for the vm vhd file. The vhd must be in the same subscription as the vm"
  type        = string
  default     = ""
}

variable "azure_image_container_name" {
  description = "Azure Container name storing the VM Image vhd file"
  type        = string
  default     = ""
}

variable "azure_image_blob_name" {
  description = "Azure blob which is the coreos vhd file"
  type        = string
  default     = ""
}

variable "azure_ignition_storage_rg" {
  description = "Existing Storage Account Resource Group for the ignition files"
  type        = string
  default     = ""
}

variable "azure_ignition_storage_account_name" {
  description = "Existing Storage Account Name for the ignition files"
  type        = string
  default     = ""
}

variable "azure_ignition_sas_container_name" {
  description = "Azure Container name storing the ignition files"
  type        = string
  default     = ""
}

variable "azure_ignition_sas_token" {
  description = "The SAS storage token string for the ignition files"
  type        = string
  default     = ""
}

variable "azure_bootlogs_storage_rg" {
  description = "Existing Storage Account Resource Group for the boot diagnostic files"
  type        = string
  default     = ""
}

variable "azure_bootlogs_storage_account_name" {
  description = "Existing Storage Account Name for the boot diagnostic files"
  type        = string
  default     = ""
}

variable "azure_bootlogs_sas_token" {
  description = "The SAS storage token string for the boot diagnostic files"
  type        = string
  default     = ""
}

variable "phased_approach" {
  description = "Define whether you want to install using a phased approach"
  type        = bool
  default     = false  
}

variable "phase1_complete" {
  description = "In order to get the IPs for the dns we want to complete phase1 first"
  type        = bool
  default     = false  
}

variable "azure_role_id_cluster" {
  description = "Role assigned to identity for the cluster (main) Resource Group"
  type        = string
  default     = ""
}

variable "azure_role_id_network" {
  description = "Role assigned to identity for the network Resource Group"
  type        = string
  default     = ""
}

variable "use_default_imageregistry" {
  description = "Define if default imageregistry is required"
  type        = bool
  default     = true
}

variable "openshift_managed_infrastructure" {
  description = "Define if the infrastructure is managed by openshift"
  type        = bool
  default     = true  
}

variable "azure_worker_root_volume_type" {
  type        = string
  description = "The type of the volume the root block device of worker nodes."
  default     = "Premium_LRS"
}
