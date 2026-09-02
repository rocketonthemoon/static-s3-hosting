# Route 53 Terraform Module

This module manages DNS records in AWS Route 53, creating ACM certificate validation CNAME records dynamically and configuring root domain Alias A records pointing to CloudFront.

## Features

- **Dynamic ACM DNS Validation Records**: Dynamically creates CNAME validation records using `for_each` over validation domain names (`["namecheap-test.me", "*.namecheap-test.me"]`).
- **Overlap Protection (`allow_overwrite = true`)**: Sets `allow_overwrite = true` on validation CNAME records to prevent duplicate record crashes in Route 53 when root and wildcard domains produce identical validation tokens.
- **CloudFront Alias Record**: Configures root domain `A` alias records pointing directly to the CloudFront distribution endpoint.

---

## Detailed Implementation & List Comprehension Mechanics

### 1. `domain_validation_options` Input Structure
ACM exports a list of domain validation objects:
```hcl
[
  {
    domain_name           = "namecheap-test.me"
    resource_record_name  = "_a1bqwdq2c3.namecheap-test.me."
    resource_record_type  = "CNAME"
    resource_record_value = "_x1yqdw2z3.acm-validations.aws."
  },
  {
    domain_name           = "*.namecheap-test.me"
    resource_record_name  = "_a1bqwdq2c3.namecheap-test.me."
    resource_record_type  = "CNAME"
    resource_record_value = "_x1yqdw2z3.acm-validations.aws."
  }
]
```

### 2. How `aws_route53_record.acm_validation` Iterates
The resource loops over `var.validation_domains = ["namecheap-test.me", "*.namecheap-test.me"]`:

- **Iteration 1 (`each.value = "namecheap-test.me"`)**:
  - `name`: Selects `dvo.resource_record_name` where `domain_name == "namecheap-test.me"` ➔ `"_a1bqwdq2c3.namecheap-test.me"` (using `[0]` index because `name` expects a single string).
  - `records`: Extracts `dvo.resource_record_value` ➔ `["_x1yqdw2z3.acm-validations.aws."]` (no `[0]` index because `records` expects a list).
  - `type`: Selects `dvo.resource_record_type` ➔ `"CNAME"` (using `[0]` index).
- **Iteration 2 (`each.value = "*.namecheap-test.me"`)**:
  - Extracts parameters for `*.namecheap-test.me`. Since the CNAME target is identical to iteration 1, `allow_overwrite = true` allows Route 53 to safely update the record without throwing duplicate errors.

---

## Data Sources & Resources Created

- `data.aws_route53_zone.main`: Discovers pre-existing Hosted Zone by domain name.
- `aws_route53_record.root`: Apex domain IPv4 `A` Alias record pointing to CloudFront (`d1234.cloudfront.net`).
- `aws_route53_record.acm_validation`: Dynamic CNAME validation records for ACM certificate issuance.

---

## Inputs

| Name | Description | Type | Required | Default |
|------|-------------|------|:--------:|:-------:|
| `domain_name` | Domain name | `string` | yes | - |
| `domain_validation_options` | ACM domain validation options list | `list(any)` | yes | - |
| `cloudfront_distribution_domain_name` | CloudFront distribution domain name | `string` | yes | - |
| `cloudfront_distribution_hosted_zone_id` | CloudFront distribution hosted zone ID | `string` | yes | - |
| `validation_domains` | List of domain names to validate | `list(string)` | yes | - |

---

## Outputs

| Name | Description | Example Exported Value |
|------|-------------|------------------------|
| `route53_zone_id` | Route 53 Hosted Zone ID | `"Z0123456789ABCDEF"` |
| `route53_zone_name` | Route 53 Hosted Zone Name | `"namecheap-test.me"` |
| `validation_record_fqdns` | List of FQDNs for ACM validation records | `["_a1bqwdq2c3.namecheap-test.me", "_a1bqwdq2c3.namecheap-test.me"]` |
