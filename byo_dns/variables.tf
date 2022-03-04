#   dns_api_ip                = module.vnet.dns_api_ip_v4
#   dns_apps_ip               = module.vnet.dns_apps_ip_v4

variable "dns_api_ip" {
  type = string
}

variable "dns_apps_ip" {
  type = string
}