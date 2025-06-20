output "all" {
  value = module.validation_records
}

output "certificate_arn" {
  value = aws_acm_certificate_validation.this.certificate_arn
}

output "main_domain" {
  description = "Main domain for certificate"
  value       = local.domain_name
}

output "all_subdomains" {
  description = "All subdomains"
  value       = local.all_subdomains
}

output "certificate_domains" {
  description = "Domains for which we'll create a certificate"
  value       = local.fqdn_subdomains
}
