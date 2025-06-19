terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# We're not going to mess with the parent zone, and will require it's handling
# and creation outside of this module
data "aws_route53_zone" "this" {
  name         = var.parent_zone
  private_zone = false
}

resource "aws_route53_record" "this" {
  for_each = {
    for dvo in var.domain_validations : dvo.domain_name => {
      resource_record_name  = dvo.resource_record_name
      resource_record_value = dvo.resource_record_value
      resource_record_type  = dvo.resource_record_type
    }
  }

  zone_id         = var.zone_id
  ttl             = 60
  name            = each.value.resource_record_name
  records         = [each.value.resource_record_value]
  type            = each.value.resource_record_type
  allow_overwrite = true

  lifecycle {
    create_before_destroy = true
  }
}
