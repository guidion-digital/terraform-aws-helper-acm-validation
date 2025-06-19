variable "parent_zone" {
  description = "Parent DNS for the records to add for var.subdomains. If var.subdomains is not provided, this will the domain that certificates will be generated for"
  type        = string
}

variable "subdomains" {
  description = "Map of subdomains and their aliases. Aliases list is required, though it can be an empty list"
  type        = map(list(string))

  default = {}
}

# FIXME: This should be a merge of it's own tags module
variable "tags" {
  description = "What to tag all resources"
}

variable "parent_zone_in_domains" {
  description = "Whether to include var.parent_zone in the list of domains for the certificate"
  type        = bool
  default     = true
}

variable "main_subdomain" {
  description = "Main subdomain to give the certificate. Defaults to the first element in the subdomains. This default is probably undesirable due to the fact that order can not be maintained when adding new subdomains"
  type        = string
  default     = null
}
