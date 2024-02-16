# Global variables
variables {
  parent_zone = "constr.manual.guidion.io"
  subdomains  = { "test-app" = [] }
  tags        = { "terraform-test" = true }
}

run "application_workspaces" {
  module {
    source = "./examples/test_app"
  }

  command = plan

  variables {
    parent_zone = var.parent_zone
    subdomains  = var.subdomains
    tags        = var.tags
  }

  # assert {
  #   condition     = NOTHING TO SEE HERE
  #   error_message = NOTHING TO SEE HERE
  # }
}
