# Read README.md before running this: it lists the AWS_* environment variables this example
# expects, which point every AWS call at MiniStack. CI sets them for you. The role and zone
# used here are created in fixtures.tf

locals {
  parent_zone = "constr.manual.guidion.io"
}

provider "aws" {
  alias = "dns_account"

  assume_role {
    role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/test-assumer"
  }
}

provider "aws" {
  alias = "requester"
}

module "helper_acm_validation" {
  source = "../../"

  providers = {
    aws.dns_account = aws.dns_account
    aws.requester   = aws.requester
  }

  parent_zone            = aws_route53_zone.test.name
  main_subdomain         = "test-app"
  subdomains             = ["foo", "bar"]
  parent_zone_in_domains = false
  tags                   = { "terraform-test" = true }

  # NOTE: This is only necessary for running this example. On a real instance,
  # there is no call for depends_on, and you need only ensure that the domains
  # you're generating for actually exist
  depends_on = [terraform_data.fixtures]
}
