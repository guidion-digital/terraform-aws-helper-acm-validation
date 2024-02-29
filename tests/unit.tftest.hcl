# Global variables
variables {
  parent_zone = "constr.manual.guidion.io"
  tags        = { "terraform-test" = true }
}

run "parent_not_in_domains" {
  module {
    source = "./examples/test_app"
  }

  command = plan

  variables {
    parent_zone            = var.parent_zone
    subdomains             = { "test-app" = ["foo"] }
    parent_zone_in_domains = false
    tags                   = var.tags
  }

  assert {
    # Why doesn't this work?!
    # https://discuss.hashicorp.com/t/terraform-test-on-object-doesnt-match/63281
    # condition = module.helper_acm_validation.certificate_domains == { "test-app.constr.manual.guidion.io" = ["foo.constr.manual.guidion.io"] }
    condition     = keys(module.helper_acm_validation.certificate_domains)[0] == "test-app.constr.manual.guidion.io"
    error_message = "The first key in var.subdomains was not the main domain in the certificate"
  }

  assert {
    condition     = module.helper_acm_validation.certificate_domains["test-app.constr.manual.guidion.io"][0] == "foo.constr.manual.guidion.io"
    error_message = "The first alias for the first key in var.subdomains was not in the list of aliases"
  }
}

run "parent_in_domains" {
  module {
    source = "./examples/test_app"
  }

  command = plan

  variables {
    parent_zone            = var.parent_zone
    subdomains             = { "test-app" = ["foo"] }
    parent_zone_in_domains = true

    tags = var.tags
  }

  assert {
    condition     = keys(module.helper_acm_validation.certificate_domains)[0] == "constr.manual.guidion.io"
    error_message = "The parent zone was not the main domain in the certificate"
  }

  assert {
    condition     = module.helper_acm_validation.certificate_domains["constr.manual.guidion.io"][0] == "test-app.constr.manual.guidion.io"
    error_message = "The first subdomain was not in the list of aliases"
  }

  assert {
    condition     = module.helper_acm_validation.certificate_domains["constr.manual.guidion.io"][1] == "foo.constr.manual.guidion.io"
    error_message = "The second subdomain (given as the first element in the subdomain list) was not in the list of aliases"
  }
}

# TODO: This can't be run until output.certificate_arn has been replaced fully
# by output.certificate_arns. We can't do that until all modules that use this
# module have been updated to use it instead
#
# run "parent_not_in_domains_multiple_main_subdomains" {
#   module {
#     source = "./examples/test_app"
#   }
#
#   command = plan
#
#   variables {
#     parent_zone            = var.parent_zone
#     subdomains             = { "test-app" = ["foo"], "test-two" = [] }
#     parent_zone_in_domains = false
#
#     tags = var.tags
#   }
#
#   assert {
#     condition     = keys(module.helper_acm_validation.certificate_domains)[0] == "test-app.constr.manual.guidion.io"
#     error_message = "The first key in var.subdomains was not the main domain in the certificate"
#   }
#
#   assert {
#     condition     = module.helper_acm_validation.certificate_domains["test-app.constr.manual.guidion.io"][0] == "foo.constr.manual.guidion.io"
#     error_message = "The first alias for the first key in var.subdomains was not in the list of aliases"
#   }
# }
