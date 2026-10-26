# Infrastructure the example depends on, which would already exist in a real account. These
# are created in MiniStack (see README.md) so the example doesn't rely on pre-existing
# infrastructure in a real AWS account.

data "aws_caller_identity" "current" {}

# The role aws.dns_account assumes in main.tf. In real use this lives in the account holding
# the zone and trusts the requesting account. MiniStack keeps each account separate, and
# we only have credentials for one, so the role, the zone and the requester all live in the
# account the AWS_* credentials belong to
resource "aws_iam_role" "test_assumer" {
  name = "test-assumer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# What the module needs to look up the zone and write the validation records into it
resource "aws_iam_role_policy" "test_assumer_route53" {
  name = "acm-validation-records"
  role = aws_iam_role.test_assumer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["route53:ListHostedZones", "route53:GetChange"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:GetHostedZone",
          "route53:ListResourceRecordSets",
          "route53:ChangeResourceRecordSets",
          "route53:ListTagsForResource",
        ]
        Resource = aws_route53_zone.test.arn
      }
    ]
  })
}

# The parent zone the module looks up. It is created outside of the module in real use too
resource "aws_route53_zone" "test" {
  name = local.parent_zone
}

# The module looks the zone up by name, and the name is known at plan time, so passing
# aws_route53_zone.test.name to it is not enough to stop the lookup happening before the
# zone exists. main.tf makes the module call depend on this instead, so that everything
# above is in place first
resource "terraform_data" "fixtures" {
  depends_on = [aws_route53_zone.test, aws_iam_role_policy.test_assumer_route53]
}
