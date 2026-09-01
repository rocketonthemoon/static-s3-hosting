# CloudFront Terraform Module

This module provisions an AWS CloudFront distribution configured with Origin Access Control (OAC) to securely distribute static website content stored in S3.

## Features

- **Origin Access Control (OAC)**: Uses SigV4 authentication between CloudFront and S3.
- **Custom SSL/TLS**: Attaches an ACM certificate (`TLSv1.2_2021` minimum protocol version).
- **Domain Aliases**: Configures custom domain CNAME aliases.
- **Origin Path Mapping**: Configured with `origin_path` (e.g. `/public`) to target the S3 website directory.
- **Custom Error Pages**: Configured with custom error response rules mapping HTTP `403` and `404` errors to a configurable error page (e.g. `/error.html`).

## Resources Created

- `aws_cloudfront_distribution.this`
- `aws_cloudfront_origin_access_control.oac`

## Inputs

| Name | Description | Type | Required | Default |
|------|-------------|------|:--------:|:-------:|
| `domain_name` | Custom domain name for CloudFront distribution CNAME alias | `string` | yes | - |
| `acm_certificate_arn` | ARN of the ACM certificate in `us-east-1` | `string` | yes | - |
| `regional_domain_name` | S3 bucket regional domain name for the origin | `string` | yes | - |
| `origin_path` | S3 bucket directory path (e.g. `/public`) | `string` | yes | - |
| `default_root_object` | Default root object file name (e.g. `index.html`) | `string` | yes | - |
| `error_page_path` | Custom error response page path (e.g. `/error.html`) | `string` | yes | - |
| `project` | Name of the project | `string` | yes | - |
| `environment` | Deployment environment name | `string` | yes | - |
| `tags` | Map of tags to apply to resources | `map(string)` | yes | - |

## Outputs

| Name | Description |
|------|-------------|
| `cloudfront_distribution_domain_name` | The domain name of the CloudFront distribution |
| `cloudfront_distribution_hosted_zone_id` | The CloudFront distribution hosted zone ID |
| `cloudfront_distribution_arn` | The ARN of the CloudFront distribution |
