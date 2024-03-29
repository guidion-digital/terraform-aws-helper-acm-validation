variable "parent_zone" {}
variable "subdomains" {}
variable "parent_zone_in_domains" {}
variable "tags" {}

provider "aws" {
  alias  = "dns_account"
  region = "us-east-1"

  assume_role {
    role_arn = "arn:aws:iam::656126335349:role/test-assumer"
  }
}

provider "aws" {
  alias  = "requester"
  region = "us-east-1"
}

module "helper_acm_validation" {
  source = "../../"

  providers = {
    aws.dns_account = aws.dns_account
    aws.requester   = aws.requester
  }

  parent_zone            = var.parent_zone
  subdomains             = var.subdomains
  parent_zone_in_domains = var.parent_zone_in_domains
  tags                   = var.tags
}
output "foo" { value = module.helper_acm_validation }
