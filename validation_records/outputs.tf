output "fqdn_list" {
  value = [for k, v in [for record_set in [for x, y in [for k, v in values(aws_route53_record.this).* : v] : y] : record_set] : v.fqdn]
}

output "certificate_arn" {
  value = var.certificate_arn
}
