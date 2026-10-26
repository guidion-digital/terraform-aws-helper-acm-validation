This example is written to run against [MiniStack](https://github.com/ministackorg/ministack), which emulates AWS locally. CI (the terrappy reusable workflows) starts MiniStack as a service and runs `terraform plan` on pull requests and `terraform apply` on pushes to `acc`.

## Requirements

The providers in `main.tf` have no endpoint, credentials or region of their own. They rely on these environment variables, which CI/CD always sets and which you must set yourself when running the example locally:

```sh
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_REGION=eu-central-1
```

Without `AWS_ENDPOINT_URL`, the example would run against whichever real AWS account your credentials point to and create a `constr.manual.guidion.io` hosted zone there.

## Running locally

```sh
docker run -d --name ministack -p 4566:4566 ministackorg/ministack:1.5.31
terraform init
terraform apply
docker rm -f ministack # MiniStack keeps everything in the container, so this clears it
```

## Notes

`fixtures.tf` creates what would already exist in a real account: the `test-assumer` role that `aws.dns_account` assumes (with a trust policy and the Route 53 permissions the module needs) and the `constr.manual.guidion.io` hosted zone. MiniStack keeps each account separate and the example only has credentials for one, so the role, the zone and the requester are all in that account rather than spread across two. MiniStack also hands out credentials for roles that don't exist yet, which is why `plan` works before the role has been created.

The module call in `main.tf` depends on `terraform_data.fixtures`, which in turn depends on everything in `fixtures.tf`. The module looks the zone up by name, and the name alone is known at plan time, so without that dependency the lookup would happen before the zone exists. The `depends_on` itself has to stay on the module block, because Terraform only accepts it there.

MiniStack reports the certificate as validated straight away, so a successful apply shows that the module creates the right resources in the right order. It does not show that real ACM would issue the certificate, since there is no real DNS propagation.
