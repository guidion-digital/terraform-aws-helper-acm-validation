variable "parent_zone" {
  description = "Parent DNS for the records to add for var.subdomains. If var.subdomains is not provided, this will the domain that certificates will be generated for"
  type        = string
}

variable "subdomains" {
  description = "Map of subdomains and their aliases. Aliases list is required, though it can be an empty list"
  type        = map(list(string))

  default = null
}

# FIXME: This should be a merge of it's own tags module
variable "tags" {
  description = "What to tag all resources"
}
