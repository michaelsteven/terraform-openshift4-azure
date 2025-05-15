variable "vm_size" {
  type        = string
  description = "The SKU ID for the bootstrap node."
}

variable "vm_image" {
  type        = string
  description = "The resource id of the vm image used for bootstrap."
}

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
  description = "The identifier for the cluster."
}

variable "identity" {
  type        = string
  description = "The user assigned identity id for the vm."
}

variable "ignition" {
  type        = string
  description = "The content of the bootstrap ignition file."
}

variable "subnet_id" {
  type        = string
  description = "The subnet ID for the bootstrap node."
}

variable "elb_backend_pool_v4_id" {
  type        = string
  description = "The external load balancer bakend pool id. used to attach the bootstrap NIC"
}

variable "elb_backend_pool_v6_id" {
  type        = string
  description = "The external load balancer bakend pool id for ipv6. used to attach the bootstrap NIC"
}

variable "ilb_backend_pool_v4_id" {
  type        = string
  description = "The internal load balancer bakend pool id. used to attach the bootstrap NIC"
}

variable "ilb_backend_pool_v6_id" {
  type        = string
  description = "The internal load balancer bakend pool id for ipv6. used to attach the bootstrap NIC"
}

variable "bootlogs_uri" {
  description = "The boot diagnostics storage account uri for storing the server boot logs"
  type        = string
  default     = ""
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "tags to be applied to created resources."
}

variable "nsg_name" {
  type        = string
  description = "The network security group for the subnet."
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

variable "azure_shared_image" {
  description = "Define if using a shared image for install"
  type        = bool
}

variable "disk_encryption_set_id" {
  description = "Encryption set to use for bootstrap disk."
  type        = string
}