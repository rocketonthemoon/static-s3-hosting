# ACM Certificate Terraform Module

This module requests an AWS Certificate Manager (ACM) SSL/TLS certificate with wildcard Subject Alternative Names (SAN) in `us-east-1` and blocks execution until DNS validation completes.

> **Important**: CloudFront requires ACM certificates to reside in the **`us-east-1` (N. Virginia)** region. When invoking this module, map an AWS provider targeting `us-east-1`:
> ```hcl
> module "acm" {
>   source    = "../../modules/acm"
>   providers = { aws = aws.us_east_1 }
>   ...
> }
> ```

---

## Features & Implementation Details

- **Wildcard SAN**: Issues certificates covering both primary domain (`example.com`) and wildcard (`*.example.com`).
- **DNS Validation**: Uses DNS-based validation via CNAME records created in Route 53.
- **Explicit Dependency Barrier (`aws_acm_certificate_validation`)**:
  - `aws_acm_certificate_validation.this` takes `var.acm_validation_records_fqdns` (the list of CNAME FQDNs created in Route 53 minus the trailing dot).
  - Acts as an explicit dependency gateway: Terraform reads this block and **does not proceed to provision CloudFront** unless the certificate is verified by ACM and marked as `ISSUED`.

---

## Data Structures & Examples

### `domain_validation_options` Output Structure
Exported by `aws_acm_certificate.this` and passed to `module.route53`:
```hcl
[
  {
    domain_name           = "your-domain.com"
    resource_record_name  = "_a1bqwdq2c3.your-domain.com."
    resource_record_type  = "CNAME"
    resource_record_value = "_x1y2edqwz3.acm-validations.aws."
  },
  {
    domain_name           = "*.your-domain.com"
    resource_record_name  = "_a1bqwdq2c3.your-domain.com."
    resource_record_type  = "CNAME"
    resource_record_value = "_x1y2edqwz3.acm-validations.aws."
  }
]
```

---

## Resources Created

- `aws_acm_certificate.this`: Requests certificate in `us-east-1` (`validation_method = "DNS"`).
- `aws_acm_certificate_validation.this`: Blocks execution until ACM detects Route 53 CNAME records and issues the certificate.

---

## Inputs

| Name | Description | Type | Required | Default |
|------|-------------|------|:--------:|:-------:|
| `domain_name` | Primary domain name for the certificate | `string` | yes | - |
| `environment` | Deployment environment name | `string` | yes | - |
| `acm_validation_records_fqdns` | List of FQDNs for DNS validation records | `list(string)` | yes | - |
| `tags` | Map of tags to apply to resources | `map(string)` | no | `{}` |

---

## Outputs

| Name | Description | Example Exported Value |
|------|-------------|------------------------|
| `acm_certificate_arn` | The ARN of the validated ACM certificate | `"arn:aws:acm:us-east-1:123456789012:certificate/a1b2c3d4-..."` |
| `domain_validation_options` | Domain validation options list returned by ACM | `[ { domain_name = "example.com", resource_record_name = "_a1b2c3...", ... } ]` |
