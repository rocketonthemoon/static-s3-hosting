# S3 Bucket Terraform Module

This module provisions a private AWS S3 bucket for static website hosting, uploads local static assets into the `/public` prefix, and secures the bucket using an S3 Bucket Policy configured for CloudFront Origin Access Control (OAC).

## Features

- **Private Storage**: Blocks all public access via `aws_s3_bucket_public_access_block`.
- **Encryption**: Enables AES256 server-side encryption by default.
- **Versioning**: Configured with versioning disabled (`status = "Disabled"`).
- **Asset Upload**: Automatically scans the `assets/` directory and uploads website files into the `/public` prefix with correct MIME types.
- **CloudFront OAC Security**: Restricts `s3:GetObject` access strictly to the CloudFront distribution via `AWS:SourceArn` matching `${aws_s3_bucket.this.arn}${var.origin_path}/*`.

## Resources Created

- `aws_s3_bucket.this`
- `aws_s3_bucket_public_access_block.this`
- `aws_s3_bucket_server_side_encryption_configuration.this`
- `aws_s3_bucket_versioning.this`
- `aws_s3_bucket_website_configuration.this`
- `aws_s3_object.website_files`
- `aws_s3_bucket_policy.cloudfront_oac`

## Inputs

| Name | Description | Type | Required | Default |
|------|-------------|------|:--------:|:-------:|
| `bucket_name` | Name of the S3 bucket | `string` | yes | - |
| `tags` | Map of tags to apply to resources | `map(string)` | no | `{}` |
| `mime_types` | Map of file extensions to Content-Type headers | `map(string)` | yes | - |
| `cloudfront_distribution_arn` | ARN of the CloudFront distribution allowed to access objects | `string` | yes | - |
| `origin_path` | Origin path prefix (e.g. `/public`) | `string` | yes | - |

## Outputs

| Name | Description |
|------|-------------|
| `bucket_name` | The name of the created S3 bucket |
| `bucket_arn` | The ARN of the created S3 bucket |
| `regional_domain_name` | The regional domain name of the S3 bucket |
