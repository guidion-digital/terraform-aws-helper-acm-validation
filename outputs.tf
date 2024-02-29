output "all" {
  value = module.validation_records
}

output "certificate_arn" {
  value = one([for this_domain in aws_acm_certificate.this : this_domain.arn])
}

output "certificate_arns" {
  value = [for this_domain in aws_acm_certificate.this : this_domain.arn]
}

output "subdomains_and_aliases" {
  description = "Flattened list of all subdomains and their aliases"

  value = local.fqdn_top_level_aliases
}

output "parent_and_subdomains" {
  description = "Parent zones mapped to lists of all subdomains"
  value       = local.parent_and_subdomains
}

output "all_subdomains" {
  description = "All subdomains"
  value       = local.all_subdomains
}

output "certificate_domains" {
  description = "Domains for which we'll create a certificate"
  value       = local.certificate_domains
}

output "fqdn_subdomains" {
  description = "Just the subdomains"
  value       = local.fqdn_subdomains
}
