terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 2.7.0"
      configuration_aliases = [aws.requester, aws.dns_account]
    }
  }
}

locals {
  parent_zone_in_domains    = var.subdomains == {} ? true : var.parent_zone_in_domains
  fqdn_subdomains           = { for this_subdomain, these_aliases in var.subdomains : "${this_subdomain}.${var.parent_zone}" => [for this_alias in these_aliases : "${this_alias}.${var.parent_zone}"] }
  top_level_subdomains      = var.subdomains == null ? [] : [for this_subdomain, these_aliases in var.subdomains : this_subdomain]
  top_level_aliases         = var.subdomains == null ? [] : [for this_subdomain, these_aliases in var.subdomains : these_aliases]
  fqdn_top_level_subdomains = [for this_top_level_subdomain in local.top_level_subdomains : "${this_top_level_subdomain}.${var.parent_zone}"]
  fqdn_top_level_aliases    = flatten([for these_aliases in local.top_level_aliases : [for this_alias in these_aliases : "${this_alias}.${var.parent_zone}"]])
  parent_and_subdomains     = { (var.parent_zone) = concat(local.fqdn_top_level_subdomains, local.fqdn_top_level_aliases) }
  all_subdomains            = toset(flatten([for these_subdomains in local.parent_and_subdomains : these_subdomains]))
  certificate_domains       = var.parent_zone_in_domains ? local.parent_and_subdomains : local.fqdn_subdomains
}

resource "aws_acm_certificate" "this" {
  provider = aws.requester

  for_each = local.certificate_domains

  domain_name               = each.key
  subject_alternative_names = [for alt_name in each.value : alt_name]
  validation_method         = "DNS"
  tags                      = var.tags
}

data "aws_route53_zone" "this" {
  provider = aws.dns_account

  name         = var.parent_zone
  private_zone = false
}

module "validation_records" {
  providers = {
    aws = aws.dns_account
  }

  for_each = aws_acm_certificate.this
  source   = "./validation_records"

  parent_zone        = var.parent_zone
  domain_validations = each.value["domain_validation_options"]
  zone_id            = data.aws_route53_zone.this.zone_id
  certificate_arn    = each.value.arn
}

resource "aws_acm_certificate_validation" "this" {
  provider = aws.requester

  for_each = module.validation_records

  certificate_arn         = each.value.certificate_arn
  validation_record_fqdns = each.value.fqdn_list
}
