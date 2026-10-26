# Lessons learned — AI/CONTEXT.md generation

Correction memory for the generator. Keep entries short; prune once the mistake stops recurring.

- The main consumer is `terraform-aws-app-apigw-lambda` (owner-confirmed). Do not name `terraform-aws-app-api-lambda` as the main consumer, even though it has more history and more local callers.
- `var.subdomains == []` in `main.tf` is always false for a `list(string)` variable. Do not describe the "force parent_zone_in_domains when nothing is given" override as working; it is dead code.
- There are no unit tests: `tests/unit.tftest.hcl` was removed. The only automated check is the Ministack plan/apply of `examples/test_app`. Do not describe the module as unit-tested.
- Output `certificate_domains` excludes the main domain despite its description. Use `all_subdomains` when describing the full domain list.
- `certificate_arn` comes from `aws_acm_certificate_validation`, not `aws_acm_certificate`. Do not "simplify" this in descriptions; the ordering is the contract.
- The module owns no hosted zones and no environments; do not invent dev/acc/prod environments for it. CI uses Ministack only (it replaced LocalStack in terrappy `v3`).
- `examples/test_app` gets its endpoint, credentials and region only from `AWS_ENDPOINT_URL`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` and `AWS_REGION`; its providers are not hardcoded to Ministack. The `test-assumer` role and the zone come from `fixtures.tf`, all in one account, so do not describe the example as testing cross-account access.
- Release gating reads terrappy's `ministack-apply-result`. `local-stack-apply-result` and `mini-stack-apply-result` are deprecated aliases; do not suggest switching back to them.
- Consumers are on two registries and two majors (public `~> 2.0` app modules vs TFC private / `~> 1.2` map-shape infra). Do not collapse them into one row.
- `master` is release-only; `acc` is the default branch and PR target.
- The "race condition" commit `e67a41b` says "Attempting"; do not report the race as fixed.
- Keep the `APIs exposed` table as the module's input/output contract and keep the domain-derivation table; the weekly regenerator cannot see `.tf` source, so it cannot rebuild them if dropped.
