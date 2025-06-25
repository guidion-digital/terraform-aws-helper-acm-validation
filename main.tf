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
  fqdn_subdomains = [for this_subdomain in var.subdomains : "${this_subdomain}.${var.parent_zone}"]

  # If no subdomains or main_subdomain have been provided, we can only use the parent_zone for the domain
  parent_zone_in_domains = var.subdomains == [] && var.main_subdomain == null ? true : var.parent_zone_in_domains
  # If the parent_zone is to be in the certificate, then set the main domain to that, otherwise:
  #   If subdomains is empty or main_subdomain is set, then use the main_subdomain for the main domain
  #   Otherwise use the first element of var.subdomains (in fqdn form)
  domain_name = local.parent_zone_in_domains ? var.parent_zone : (var.subdomains == [] || var.main_subdomain != null ? "${var.main_subdomain}.${var.parent_zone}" : local.fqdn_subdomains[0])
  # All of this together should mean that local.domain_name can only fail to be set if:
  #   var.subdomains is empty AND var.main_subdomain is null AND we somehow end up with local.parent_zone_in_domains as false (which shouldn't be possible)

  # Can be used by caller for creating DNS records
  all_subdomains = concat([local.domain_name], local.fqdn_subdomains)
}

resource "aws_acm_certificate" "this" {
  provider = aws.requester

  domain_name               = local.domain_name
  subject_alternative_names = local.fqdn_subdomains
  validation_method         = "DNS"
  tags                      = var.tags

  lifecycle {
    create_before_destroy = true
  }
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

  source = "./validation_records"

  parent_zone        = var.parent_zone
  domain_validations = aws_acm_certificate.this.domain_validation_options
  zone_id            = data.aws_route53_zone.this.zone_id
  certificate_arn    = aws_acm_certificate.this.arn
}

resource "aws_acm_certificate_validation" "this" {
  provider = aws.requester

  certificate_arn         = module.validation_records.certificate_arn
  validation_record_fqdns = module.validation_records.fqdn_list

  lifecycle {
    create_before_destroy = true
    replace_triggered_by = [
      aws_acm_certificate.this
    ]
  }
}
