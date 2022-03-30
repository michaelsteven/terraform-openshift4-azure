variable "cluster_name" {
  description = "The cluster name of the domain for the cluster that all DNS records must belong"
  type        = string
}

variable "base_domain" {
  description = "The base domain used for public records"
  type        = string
}

variable "internal_lb_ipaddress_v4" {
  description = "External API's LB IP v4 address"
  type        = string
}

variable "internal_lb_ipaddress_v6" {
  description = "External API's LB IP v6 address"
  type        = string
}

variable "internal_lb_apps_ipaddress_v4" {
  description = "External Apps LB IP v4 address"
  type        = string
}

variable "internal_lb_apps_ipaddress_v6" {
  description = "External Apps LB IP v6 address"
  type        = string
}

variable "use_ipv4" {
  type        = bool
  description = "This value determines if this is cluster should use IPv4 networking."
}

variable "use_ipv6" {
  type        = bool
  description = "This value determines if this is cluster should use IPv6 networking."
}

variable "infoblox_fqdn" {
  type        = string
  description = "The Infoblox host fully qualified domain name or ip address"
  default     = ""
}

variable "infoblox_username" {
  type        = string
  description = "The Infoblox credentials username"
  default     = ""
}

variable "infoblox_password" {
  type        = string
  description = "The Infoblox credentials password"
  default     = ""
}

variable "infoblox_allow_any" {
  type        = bool
  description = "Is the Infoblox allow any policy set to default, allowing wildcard dns names"
  default     = false
}

variable "infoblox_apps_dns_entries" {
  type        = list(string)
  description = "The list of openshift *.apps dns entires if wildcards are not supported by Infoblox"
  default     = []
}
