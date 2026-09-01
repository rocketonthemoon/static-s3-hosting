# ACM Certificate Terraform Module

This module requests an AWS Certificate Manager (ACM) SSL/TLS certificate with wildcard Subject Alternative Names (SAN) and waits for DNS validation to complete.

> **Important**: CloudFront requires ACM certificates to reside in the **`us-east-1` (N. Virginia)** region. When invoking this module, map an AWS provider targeting `us-east-1`:
> ```hcl
> module "acm" {
>   source    = "../../modules/acm"
>   providers = { aws = aws.us_east_1 }
>   ...
> }
> ```

## Features

- **Wildcard SAN**: Issues certificates covering both `example.com` and `*.example.com`.
- **DNS Validation**: Uses DNS-based validation records.
- **Validation Waiting**: Utilizes `aws_acm_certificate_validation` to block until ACM marks the certificate as `ISSUED`.

## Resources Created

- `aws_acm_certificate.this`
- `aws_acm_certificate_validation.this`

## Inputs

| Name | Description | Type | Required | Default |
|------|-------------|------|:--------:|:-------:|
| `domain_name` | Primary domain name for the certificate | `string` | yes | - |
| `environment` | Deployment environment name | `string` | yes | - |
| `acm_validation_records_fqdns` | List of FQDNs for DNS validation records | `list(string)` | yes | - |
| `tags` | Map of tags to apply to resources | `map(string)` | no | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| `acm_certificate_arn` | The ARN of the validated ACM certificate |
| `domain_validation_options` | Domain validation options returned by ACM |
