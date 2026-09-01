# Route 53 Terraform Module

This module manages DNS records in AWS Route 53, creating ACM certificate validation CNAME records dynamically and configuring root domain Alias A records pointing to CloudFront.

## Features

- **Dynamic ACM DNS Validation Records**: Dynamically creates CNAME validation records using `for_each` over validation domain names.
- **CloudFront Alias Record**: Configures root domain `A` alias records pointing to the CloudFront distribution endpoint.

## Data Sources & Resources Created

- `data.aws_route53_zone.main`
- `aws_route53_record.root`
- `aws_route53_record.acm_validation`

## Inputs

| Name | Description | Type | Required | Default |
|------|-------------|------|:--------:|:-------:|
| `domain_name` | Domain name | `string` | yes | - |
| `domain_validation_options` | ACM domain validation options list | `list(any)` | yes | - |
| `cloudfront_distribution_domain_name` | CloudFront distribution domain name | `string` | yes | - |
| `cloudfront_distribution_hosted_zone_id` | CloudFront distribution hosted zone ID | `string` | yes | - |
| `validation_domains` | List of domain names to validate | `list(string)` | yes | - |

## Outputs

| Name | Description |
|------|-------------|
| `route53_zone_id` | Route 53 Hosted Zone ID |
| `route53_zone_name` | Route 53 Hosted Zone Name |
| `validation_record_fqdns` | List of FQDNs for ACM certificate validation CNAME records |
