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

`var.parent_zone` is the zone for which you're asking subdomain certificates for. By default, it is the _main_ domain for which certificates will be generated, with the values in `var.subdomains` being the SANs. This behaviour can be changed by setting `var.parent_zone_in_domains` to `false`, in which case the first key in `var.subdomains` is the main domain, and the values in it's list are the SANs.

`var.subdomains` is a map of lists, the keys for which are the main subdomains, and the list element values any aliases you would like to use for that subdomain. If you provide `var.subdomains` at all, you must give an empty list if there are no aliases, as in the example.

For example:

```hcl

# Will give a certificate valid solely for bar.com
...
  parent_zone = "bar.com"
...

# Will give a certificate valid for bar.com and foo.bar.com
  parent_zone = "bar.com"
  subdomains  = { "foo" = [] }

# Will give a certificate valid for bar.com, foo.bar.com, and cow.bar.com
  parent_zone = "bar.com"
  subdomains  = { "foo" = ["cow"] }

# Will give a certificate valid for foo.bar.com, and cow.bar.com
  parent_zone = "bar.com"
  subdomains = { "foo" = ["cow"] }
  parent_zone_in_domains = false
```
