variable "domain_validations" {
  description = "TODO"
}

variable "zone_id" {
  description = "TODO"
}

variable "certificate_arn" {
  description = "TODO"
}

variable "parent_zone" {
  description = "Parent DNS for the records to add for var.subdomains"
  type        = string
}
