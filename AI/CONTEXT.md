---
repo: terraform-aws-helper-acm-validation
project_name: Helper module — ACM certificate DNS validation
owner: Cinfra
domain: cloud-infrastructure
criticality: medium
summary: Reusable Terraform helper module that requests a single DNS-validated AWS ACM certificate in a "requester" account, writes the validation CNAMEs into a public Route 53 zone that may live in a different "dns_account", and only returns the certificate ARN once validation has completed.
main_stack:
  - Terraform
  - AWS provider (hashicorp/aws)
  - GitHub Actions
main_systems:
  - AWS Certificate Manager (ACM)
  - AWS Route 53
  - Terraform Registry (public) and Terraform Cloud private registry (app.terraform.io/guidion)
  - Ministack (CI)
last_reviewed: 2026-10-26
review_confidence: high
generated_by: AI-assisted
validated_by: Afraz
---

# terraform-aws-helper-acm-validation

## Overview

A small, single-purpose Terraform module whose main consumer is `terraform-aws-app-apigw-lambda`, which calls it from `dns.tf` to get the certificate for each application's API Gateway custom domain names. The only other callers are older 1.x wildcard-certificate uses for top-level zones (see External integrations). It hides the cross-account dance of "certificate lives in account A, the DNS zone lives in account B" behind two provider aliases. It has no runtime, no state of its own, and no deployment target — it is published as a versioned module and only ever runs inside a consumer's Terraform plan/apply.

- **Owner:** Cinfra (`repo_owner` in `.github/workflows/regenerate-context.yaml`; `.github/CODEOWNERS` assigns `* @guidion-digital/cinfra`)
- **Main stack:** Terraform, `hashicorp/aws` provider (declared `>= 2.7.0`, see Known risks), GitHub Actions
- **Environment:** Whatever AWS accounts the caller wires into `aws.requester` and `aws.dns_account`. Consumers creating API Gateway edge certificates use `us-east-1`. The bundled example and CI run against Ministack, with the region taken from `AWS_REGION` (`eu-central-1` in CI).

---

## Purpose and responsibilities

Does:

- Compute the certificate's main domain and SAN list from `parent_zone`, `subdomains`, `main_subdomain` and `parent_zone_in_domains` (`main.tf` `locals`).
- Create one `aws_acm_certificate.this` (DNS validation, `create_before_destroy`) with `provider = aws.requester`.
- Look up the existing **public** Route 53 zone named `parent_zone` with `provider = aws.dns_account`.
- Create one `aws_route53_record` validation record per `domain_validation_options` entry, via the `validation_records/` submodule, in the DNS account's zone (TTL 60, `allow_overwrite = true`).
- Create `aws_acm_certificate_validation.this` in the requester account and expose its `certificate_arn`, so consumers cannot attach the certificate before it is issued.
- Return the domain list it used (`main_domain`, `all_subdomains`) so callers can create matching DNS/API Gateway resources.

Does not do (delegated to):

- Create or manage hosted zones → the caller / zone modules (e.g. `terraform-aws-infra-zones`). The comment in `validation_records/main.tf` is explicit: "We're not going to mess with the parent zone, and will require it's handling and creation outside of this module".
- Create application DNS records (A/alias/CNAME for the service itself) → the consumer (e.g. `dns.tf` in `terraform-aws-app-api-lambda` / `terraform-aws-app-apigw-lambda`).
- Configure providers, assume-role ARNs or credentials → the caller passes fully configured `aws.requester` and `aws.dns_account` providers.
- Issue multiple certificates per call → since `cae19e0` ("Subdomain fix", BREAKING), one module instance = one certificate. Callers needing several use `for_each`/`count` on the module.
- Private hosted zones → the zone lookup hard-codes `private_zone = false`.

---

## Source of truth / data ownership

| Domain object / data                           | Source of truth                                             | This system role                               | Notes                                                                                                                  |
| ---------------------------------------------- | ----------------------------------------------------------- | ---------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| ACM certificate (per module instance)          | AWS ACM in the requester account                            | Owns (creates/replaces)                        | `aws_acm_certificate.this`; `create_before_destroy = true` so a SAN change issues a new cert before the old is deleted |
| ACM validation status                          | AWS ACM                                                     | Reads/waits on                                 | `aws_acm_certificate_validation.this` blocks apply until ACM reports the cert as issued                                |
| ACM DNS validation CNAME records               | AWS Route 53 in the DNS account                             | Owns (creates, and overwrites if pre-existing) | `validation_records/main.tf`, `allow_overwrite = true`, keyed by `dvo.domain_name`                                     |
| Public hosted zone `parent_zone`               | Route 53 in the DNS account, managed by caller/zone modules | Reads only                                     | Looked up by **name** twice (root `main.tf` and `validation_records/main.tf`)                                          |
| Certificate domain naming (main domain + SANs) | This module's `locals`                                      | Owns the derivation                            | Consumers rely on `main_domain` / `all_subdomains` outputs to name API Gateway domain resources                        |

---

## External integrations

| System                                                               | Type                                                                                                                        | Direction       | Notes                                                                                                                                                              |
| -------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| AWS ACM (requester account)                                          | AWS API via `aws.requester` provider                                                                                        | → outbound      | Requests and waits on certificate validation                                                                                                                       |
| AWS Route 53 (DNS account)                                           | AWS API via `aws.dns_account` provider                                                                                      | → outbound      | Zone lookup by name + validation record writes; typically cross-account via the caller's `assume_role`                                                             |
| `terraform-aws-app-api-lambda` (`dns.tf`)                            | Terraform module call, public registry `guidion-digital/helper-acm-validation/aws` `~> 2.0`                                 | ← inbound       | `count`-gated on `var.acm_certificate_arn == null`; always passes `main_subdomain` (falls back to `application_name`)                                              |
| `terraform-aws-app-apigw-lambda` (`dns.tf`)                          | Terraform module call, public registry `~> 2.0`                                                                             | ← inbound       | Public copy of `terraform-aws-app-api-lambda` (fresh history from 2026-06-19), identical `dns.tf`; uses `main_domain`, `all_subdomains`, `certificate_arn` outputs |
| `terraform-aws-infra-zones` (`main.tf`)                              | Terraform module call, private TFC registry `app.terraform.io/guidion/helper-acm-validation/aws` pinned `1.2.0-alpha-0.0.3` | ← inbound       | Uses the **1.x map shape** `subdomains = { "*" = [] }` for wildcard certs per zone                                                                                 |
| `infrastructure` (`projects/cloud-infra/networking/certificates.tf`) | Terraform module call, public registry `~> 1.2`                                                                             | ← inbound       | Wildcard certs for `guidion.io`, `guidion.com`, `guidion.nl`, `guidion.net` using the **1.x map shape**                                                            |
| `guidion-digital/terrappy`                                           | Reusable GitHub workflows `@v3`                                                                                             | → outbound (CI) | Ministack plan on PR, Ministack apply on push to `acc`                                                                                                           |
| `guidion-digital/release-workflows`                                  | Reusable GitHub workflows `@v2`                                                                                             | → outbound (CI) | Workflow self-test, `acc` → `master` merge, release tagging                                                                                                        |
| `guidion-digital/context-layer`                                      | Reusable GitHub workflow `@0.0.22`                                                                                          | → outbound (CI) | Weekly regeneration of this file (OpenAI); `AI/LessonsLearned.md` is appended to its prompt                                                                        |

Direction legend:

- `→ outbound`: this system calls another system
- `← inbound`: another system calls this system
- `↔ bidirectional`: both systems exchange data

The consumer rows come from local checkouts of sibling `guidion-digital` repos on 2026-10-26 (backup copies excluded); they are not exhaustive — any repo or TFC workspace not cloned locally is missing.

---

## APIs exposed

This module's "API" is its Terraform interface. Inputs and outputs are a contract with every consumer listed above.

| Endpoint / method                                     | Purpose                                                                                                                                                          | Consumer                                                              |
| ----------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| provider `aws.requester` (configuration alias)        | Account/region in which the ACM certificate is created and validated                                                                                             | All consumers                                                         |
| provider `aws.dns_account` (configuration alias)      | Account holding the public zone; may be identical to `aws.requester` when no cross-account is needed                                                             | All consumers                                                         |
| input `parent_zone` (string, required)                | Name of the existing public Route 53 zone; looked up by name                                                                                                     | All consumers                                                         |
| input `subdomains` (`list(string)`, default `[]`)     | Labels prefixed to `parent_zone` and added as SANs. **Was `map(list)` in 1.x**                                                                                   | 2.x consumers                                                         |
| input `main_subdomain` (string, default `null`)       | Label used for the certificate's `domain_name` when the parent zone is not in the cert; ignored when `parent_zone_in_domains` is effectively true                | App modules (always set)                                              |
| input `parent_zone_in_domains` (bool, default `true`) | Use `parent_zone` itself as the certificate's main domain                                                                                                        | App modules (via `DEPRECATED_acm_mode` / `parent_zone_in_domains`)    |
| input `tags` (untyped, required)                      | Tags on the ACM certificate only (records are not taggable)                                                                                                      | All consumers                                                         |
| output `certificate_arn`                              | ARN taken from `aws_acm_certificate_validation.this`, i.e. only known once validation has completed. This ordering is the reason for commits `966369c`/`e67a41b` | App modules (API Gateway domain names), `terraform-aws-infra-zones`   |
| output `main_domain`                                  | The certificate's `domain_name` (parent zone, or `main_subdomain.parent_zone`, or the first subdomain FQDN)                                                      | App modules (`aws_api_gateway_domain_name.parents`)                   |
| output `all_subdomains`                               | `[main_domain] + every subdomain FQDN`; may contain duplicates (see Known risks)                                                                                 | App modules (`toset()` for `aws_api_gateway_domain_name.alt_domains`) |
| output `certificate_domains`                          | Only the subdomain FQDNs (the SAN list) — despite its description it does **not** include the main domain                                                        | No known consumer                                                     |
| output `all`                                          | The whole `validation_records` submodule (its `fqdn_list` and `certificate_arn`)                                                                                 | No known consumer                                                     |

### Domain derivation (behaviour contract)

| `parent_zone_in_domains` | `subdomains` | `main_subdomain` | Certificate `domain_name`                                                           | SANs                                                 |
| ------------------------ | ------------ | ---------------- | ----------------------------------------------------------------------------------- | ---------------------------------------------------- |
| `true` (default)         | any          | ignored          | `parent_zone`                                                                       | each `sub.parent_zone`                               |
| `false`                  | non-empty    | `null`           | first `subdomains` FQDN                                                             | each `sub.parent_zone` (includes the main one again) |
| `false`                  | any          | set              | `main_subdomain.parent_zone`                                                        | each `sub.parent_zone`                               |
| `false`                  | `[]`         | `null`           | **plan fails** with `Invalid index` on `local.fqdn_subdomains[0]` — see Known risks | —                                                    |

---

## APIs / services consumed

| Service                                               | Purpose                                                                            | Authentication                                                                                                                             |
| ----------------------------------------------------- | ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| AWS ACM API (requester account)                       | `RequestCertificate`, describe/wait for validation                                 | Whatever credentials the caller's `aws.requester` provider has (CI/TFC workspace credentials)                                              |
| AWS Route 53 API (DNS account)                        | `ListHostedZones` lookup by name, `ChangeResourceRecordSets` for validation CNAMEs | Caller's `aws.dns_account` provider, typically `assume_role` into the DNS account (see `examples/test_app/main.tf`) |
| Terraform Cloud private registry (`app.terraform.io`) | Dependabot terraform ecosystem updates                                             | `TFC_PLANNER_API_TOKEN` GitHub secret (referenced in `.github/dependabot.yml`, value not in repo)                                          |
| OpenAI API                                            | Weekly `AI/CONTEXT.md` regeneration                                                | `OPENAI_API_KEY` GitHub secret                                                                                                             |
| Ministack (`ministackorg/ministack:1.5.31`)           | CI plan/apply of `examples/*` via plain `terraform` on `localhost:4566`            | n/a (local emulator in the runner)                                                                                                         |

---

## Deployment

**CI/CD:** GitHub Actions, entirely via reusable workflows.

- `test-plan.yaml` — on PR to `acc`: `release-workflows` self-test → `terrappy` `tfc-test-helper-module-plan@v3` (only if a `*.tf` file changed: runs `terraform init && terraform plan` in each `examples/*` dir against a Ministack service container) → release dry-run.
- `test-apply-and-release.yaml` — on push to `acc`: `terrappy` `tfc-test-helper-module-apply@v3` against Ministack. If the apply succeeded → merge `acc` into `master` and cut a release tag. If no Terraform files changed (apply skipped) → merge `acc` into `master` without a release.
- `regenerate-context.yaml` — Mondays 06:00 UTC + manual dispatch; opens a PR updating this file.
- `dependabot.yml` — daily grouped updates for GitHub Actions and Terraform.

**Infra:** None owned. Published as a Terraform module; tags such as `2.0.1`, `2.0.2`, `2.0.3-alpha-0.0.1` are the release artifacts. Consumers reference it from both the public registry (`guidion-digital/helper-acm-validation/aws`) and the TFC private registry (`app.terraform.io/guidion/helper-acm-validation/aws`).

**Branch strategy:** `acc` is the default branch and the PR target; `master` is release-only and is merged from `acc` by CI. Never PR into `master`.

**Environments:**

- Ministack (CI only). There is no deployed environment for this repo; "production" is whichever consumer workspace applies a given tag.

---

## Architectural notes and key decisions

- **Two provider aliases instead of a role-ARN input.** The module declares `configuration_aliases = [aws.requester, aws.dns_account]` so the caller owns all credential/assume-role configuration. Passing the same provider twice is the supported way to do single-account validation (README).
- **One certificate per module instance (2.x).** `cae19e0` replaced the 1.x `subdomains = map(list(string))` (one cert per map key) with a flat list plus `main_subdomain`. The commit message states the old behaviour "didn't work correctly". 1.x consumers must be rewritten, not just re-pinned.
- **Main domain defaults to the parent zone.** `parent_zone_in_domains` defaults to `true`. The `main_subdomain` description warns that defaulting to the first list element is undesirable because list order is not stable when subdomains are added — changing `domain_name` forces certificate replacement.
- **Certificate ARN is only released after validation.** Root output `certificate_arn` reads from `aws_acm_certificate_validation.this`, and `validation_records`' `certificate_arn` output has `depends_on = [aws_route53_record.this]` (`966369c`). `e67a41b` then removed `replace_triggered_by = [aws_acm_certificate.this]` from the validation resource (a replaced cert already changes `certificate_arn`, which forces replacement anyway). The commit is titled "Attempting to fix race condition" — it has not been confirmed as a fix.
- **Validation records are a submodule** (`validation_records/`) receiving the DNS provider as its default `aws`. It takes `zone_id` from the root and has its own unused zone lookup (see Known risks).
- **`create_before_destroy` on certificate, records and validation**, so that certificate rotation does not leave consumers (API Gateway domain names, which also use `create_before_destroy`) pointing at a deleted ARN.

---

## Known risks / fragile areas

- **Empty `subdomains` + `parent_zone_in_domains = false` + no `main_subdomain` breaks plan (dormant, actually broken).** `main.tf:15` and `main.tf:19` test `var.subdomains == []`. Because `var.subdomains` is typed `list(string)` and `[]` is an empty tuple, that comparison is **always false** in Terraform (verified: typed empty list `== []` → `false`, `length(...) == 0` → `true`). So the override that is meant to force `parent_zone_in_domains = true` never fires, and that input combination fails with `Invalid index` on `local.fqdn_subdomains[0]` (reproduced locally). Default inputs and current app-module consumers (which always pass `main_subdomain`) do not hit it. Fix is `length(var.subdomains) == 0` in both places.
- **`allow_overwrite = true` on validation records** silently takes over any existing record with the same name in the DNS account's zone. It is likely load-bearing: ACM issues identical validation CNAMEs for an apex and its wildcard (and for the same name across certificates in one account), and records are keyed by `dvo.domain_name`, so two keys can target one DNS record. The flip side: when one of those resources is destroyed, it deletes the shared record from under the other. Do not remove it without checking wildcard + apex consumers.
- **Zone looked up by name, public only.** Both `data "aws_route53_zone"` blocks use `name = var.parent_zone, private_zone = false`. If the DNS account has two public zones with the same name, or the zone is private, plan fails. The lookup in `validation_records/main.tf` is **unused** (the submodule uses `var.zone_id`); it is a redundant API call and a second failure point.
- **Label disagrees with wiring:** output `certificate_domains` is described as "Domains for which we'll create a certificate" but returns only `local.fqdn_subdomains` — the main domain is missing whenever it is the parent zone or `main_subdomain`. Use `all_subdomains` for the full list.
- **`all_subdomains` can contain duplicates** (main domain is also the first subdomain, or `main_subdomain` is also in `subdomains`). Current consumers wrap it in `toset()`; a consumer using it in `count` or as a list would double up.
- **Renaming the main domain replaces the certificate.** Changing `parent_zone_in_domains`, `main_subdomain`, or reordering `subdomains` when `main_subdomain` is null changes `domain_name`, which forces a new certificate and new validation in every consumer that bumps to that version.
- **Provider lower bound is misleading.** `version = ">= 2.7.0"` but the module iterates `domain_validation_options` as a set in `for_each`, which requires AWS provider 3.x+ semantics. Consumers on old providers would get a confusing error rather than a constraint failure.
- **`tags` is untyped** and carries `# FIXME: This should be a merge of it's own tags module` (`variables.tf:19`). Anything is accepted.
- **Undocumented submodule inputs:** `validation_records/variables.tf` has `description = "TODO"` for `domain_validations`, `zone_id` and `certificate_arn`.
- **`validation_records` `fqdn_list` output** is a four-level nested `for` that reduces to `[for r in aws_route53_record.this : r.fqdn]`. Harmless, but easy to break when editing.
- **Two registries, two major versions in use.** `terraform-aws-infra-zones` (TFC private, `1.2.0-alpha-0.0.3`) and `infrastructure` networking wildcard certs (public, `~> 1.2`) are on the 1.x map interface; the app modules are on `~> 2.0`. A 3.x breaking change, or a re-tag of 1.x, affects these groups differently.
- **No unit tests.** The stale 1.x `tests/unit.tftest.hcl` has been removed and nothing replaced it. The only automated check is CI's Ministack plan (PRs) and apply (pushes to `acc`) of `examples/test_app`, which runs only when a `*.tf` file changes and asserts nothing beyond a successful apply. The domain-derivation logic in `main.tf` `locals` has no test coverage.
- **README example typo:** the last example passes `[ "foo", "mow"]` but claims a certificate for `cow.bar.com`.
- **The example only proves wiring, not issuance.** `examples/test_app/main.tf` configures neither endpoint, credentials nor region on its two provider aliases; it relies on `AWS_ENDPOINT_URL`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` and `AWS_REGION`, which terrappy sets to point at Ministack and which `examples/test_app/README.md` makes a requirement. Run without `AWS_ENDPOINT_URL`, it would create the zone in a real account. It also creates the `constr.manual.guidion.io` zone itself, and `examples/test_app/fixtures.tf` creates the `test-assumer` role that `aws.dns_account` assumes. Ministack keeps accounts separate and the example only has credentials for one, so the role, zone and requester share an account: `assume_role` is exercised, but not across accounts. Ministack also issues credentials for roles that don't exist and reports validation as complete immediately. The module call needs `depends_on = [terraform_data.fixtures]` (which depends on the zone and the role's policy in `fixtures.tf`): the zone name is known at plan time, so without it the module's by-name zone lookups run before the zone exists and plan fails with `no matching Route 53 Hosted Zone found`.
- **Release gating depends on a terrappy output name.** `test-apply-and-release.yaml` gates the merge-to-`master` and release jobs on `needs.tests-apply.outputs.ministack-apply-result` from terrappy `v3`. A misspelt or renamed output does not fail the workflow: it resolves to an empty string, so after a successful apply `terraform-module-change` and `release-module-version` are skipped and `workflow-change` merges into `master` without cutting a release. This happened while `v3` briefly published only `mini-stack-apply-result`; `local-stack-apply-result` and `mini-stack-apply-result` remain as deprecated aliases.

---

## AI assistant guidance

When modifying this repo:

- Treat every input, output and provider alias as a public contract. Renaming or retyping any of them is a breaking change requiring a major version and coordinated updates in `terraform-aws-app-api-lambda`, `terraform-aws-app-apigw-lambda`, `terraform-aws-infra-zones` and `infrastructure`.
- Keep `certificate_arn` sourced from `aws_acm_certificate_validation.this`. Never return `aws_acm_certificate.this.arn` directly — consumers depend on the ARN only resolving after validation.
- Do not make the module create or modify hosted zones; zones are owned elsewhere.
- Use `length(x) == 0`, not `x == []`, for typed collections in this codebase.
- Changes to the domain derivation in `main.tf` `locals` can replace live certificates in every consumer; spell out the effect in the PR and the release notes.
- Do not remove `allow_overwrite` or `create_before_destroy` without considering apex + wildcard certificates sharing a validation record.
- PRs go to `acc`, never `master`. CI only runs the Ministack plan when a `*.tf` file changes, and there are no unit tests. If you touch the domain derivation, check the cases in the Domain derivation table by hand, or add `terraform test` coverage.
- Ask Cinfra before changing provider wiring (`configuration_aliases`) or the registry/release flow.

If this file contradicts the actual code, the code wins — flag the discrepancy to the repo owner instead of trusting the doc.

---

## Roadmap / active migrations

- [ ] Migrate remaining 1.x consumers (`terraform-aws-infra-zones`, `infrastructure` `projects/cloud-infra/networking/certificates.tf`) to the 2.x list interface.
- [ ] `tags` should use the shared tags module (`FIXME` in `variables.tf`).

---

## Freshness

- **Last reviewed:** 2026-10-26
- **Review confidence:** high
- **Generated by:** AI-assisted
- **Validated by:** Afraz
- **Update when:** integrations change, stack changes, exposed APIs change, data ownership changes, or a relevant architectural decision is made

Bootstrap generation, validated by Afraz (Cinfra) on 2026-10-26. Every tracked file in the repo was read in full during generation. The `== []` behaviour and the `Invalid index` failure were reproduced locally with Terraform 1.6.1. `examples/test_app` was planned and applied against Ministack 1.5.31 with only the four `AWS_*` variables set. Consumer usage was characterised from local checkouts of sibling repos (`terraform-aws-app-api-lambda`, `terraform-aws-app-apigw-lambda`, `terraform-aws-infra-zones`, `infrastructure`) and is not exhaustive. CI behaviour was read from `terrappy` `v3` and `context-layer` `0.0.22` sources. ACM behaviour around shared validation CNAMEs is from AWS documentation knowledge, not observed in this repo.
