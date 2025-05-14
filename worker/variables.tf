variable "region" {
  type        = string
  description = "The region for the deployment."
}

variable "resource_group_name" {
  type        = string
  description = "The resource group name for the deployment."
}

variable "cluster_id" {
  type = string
}

variable "vm_size" {
  type = string
}

variable "vm_image" {
  type        = string
  description = "The resource id of the vm image used for workers."
}

variable "identity" {
  type        = string
  description = "The user assigned identity id for the vm."
}

variable "instance_count" {
  type = string
}

variable "elb_backend_pool_v4_id" {
  type = string
}

variable "elb_backend_pool_v6_id" {
  type = string
}

variable "ilb_backend_pool_v4_id" {
  type = string
}

variable "ilb_backend_pool_v6_id" {
  type = string
}

variable "ignition_worker" {
  type    = string
  default = ""
}

variable "kubeconfig_content" {
  type    = string
  default = ""
}

variable "subnet_id" {
  type        = string
  description = "The subnet to attach the workers to."
}

variable "os_volume_type" {
  type        = string
  description = "The type of the volume for the root block device."
}

variable "os_volume_size" {
  type        = string
  description = "The size of the volume in gigabytes for the root block device."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "tags to be applied to created resources."
}

variable "bootlogs_uri" {
  description = "The boot diagnostics storage account uri for storing the server boot logs"
  type        = string
  default     = ""
}

variable "ignition" {
  type = string
}

variable "availability_zones" {
  type        = list(string)
  description = "List of the availability zones in which to create the workers. The length of this list must match instance_count."
}

variable "private" {
  type        = bool
  description = "This value determines if this is a private cluster or not."
}

variable "use_ipv4" {
  type        = bool
  description = "This value determines if this is cluster should use IPv4 networking."
}

variable "use_ipv6" {
  type        = bool
  description = "This value determines if this is cluster should use IPv6 networking."
}

variable "emulate_single_stack_ipv6" {
  type        = bool
  description = "This determines whether a dual-stack cluster is configured to emulate single-stack IPv6."
}

variable "outbound_udr" {
  type    = bool
  default = false

  description = <<EOF
This determined whether User defined routing will be used for egress to Internet.
When false, Standard LB will be used for egress to the Internet.

This is required because terraform cannot calculate counts during plan phase completely and therefore the `vnet/public-lb.tf`
conditional need to be recreated. See https://github.com/hashicorp/terraform/issues/12570
EOF
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

variable "managed_infrastructure" {
  description = "Define if nodes are is managed by openshift"
  type        = bool
  default     = true  
}

variable "node_role" {
  description = "Identify the node role as a worker or infra node"
  type        = string
  default     = "worker"
}

variable "infra_data_disk_size_GB" {
  type          = string
  description   = "Size of data disk for infra nodes" 
  default       = 0
}

variable "number_of_disks_per_node" {
  type          = string
  description   = "Number of data disk per infra node" 
  default       = 0
}

variable "azure_shared_image" {
  description = "Define if using a shared image for install"
  type        = bool
}

variable "worker_data_disk_size_GB" {
  type          = string
  description   = "Size of storage disk for worker nodes" 
  default       = 0
}

variable "disk_encryption_set_id" {
  description = "Encryption set to use for worker disks."
  type        = string
}