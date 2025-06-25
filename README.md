Performs necessary tasks to get valid ACM certificates for domains passed to it.

# Usage

## Required Providers

Two AWS providers are required for this module: `aws.requester` and `aws.dns_account`. As in the [examples](./examples), you can pass them like this:

```hcl
  providers = {
    aws.dns_account = aws.dns_account
    aws.requester   = aws.requester
  }
```

`dns_account` in the example is one in which the DNS records are held, and this account is allowed to assume via the assume role shown. This is so that the module can still create records for the zones, even if they're in another account. The certificates will still be created in the requesting account (`requestor`), but the DNS entries needed to complete validation will be created in the account holding the zone.

If both the zones and the certificates are to be created in the calling account, you can provide identical providers, both without an `assume_role` block.

## Domains

`var.parent_zone` is the zone for which you're asking subdomain certificates for. By default, it is included in the certificates domains. This behaviour can be changed by setting `var.parent_zone_in_domains` to `false`.

`var.main_subdomain` is used for the `domain` setting for the certificate. The first element of the subdomain list will be used if this is omitted. Will have no effect if `var.parent_zone_in_domains` evaluates to true (in which case `var.parent_zone` is used as the main domain).

`var.subdomains` is a list of additional aliases to add to the certificate.

For example:

```hcl

# Will give a certificate valid solely for bar.com
  parent_zone = "bar.com"

# Will give a certificate valid for bar.com and foo.bar.com
  parent_zone = "bar.com"
  subdomains  = [ "foo" ]

# Will give a certificate valid for bar.com, foo.bar.com, and moo.bar.com
  parent_zone = "bar.com"
  subdomains  = [ "foo", "moo" ]

# Will give a certificate valid for foo.bar.com, and cow.bar.com
  parent_zone = "bar.com"
  subdomains = [ "foo", "mow"]
  parent_zone_in_domains = false
```
