output "fqdn_list" {
  value = [for dvo in var.domain_validations : dvo.resource_record_name]
}

output "certificate_arn" {
  value = var.certificate_arn

  depends_on = [aws_route53_record.this]
}
