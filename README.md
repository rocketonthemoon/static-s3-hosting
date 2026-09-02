# AWS Static Website Infrastructure

Infrastructure-as-Code repository for deploying a secure, high-performance static website on AWS using Terraform.

## Architecture Overview

- **Storage**: AWS S3 private bucket containing static assets located inside the `/public` prefix.
- **Content Delivery**: AWS CloudFront Distribution configured with Origin Access Control (OAC) to securely serve S3 content over HTTPS.
- **SSL/TLS Certificate**: AWS Certificate Manager (ACM) certificate issued in `us-east-1` (N. Virginia) with automated DNS validation.
- **DNS & Routing**: AWS Route 53 managing domain validation records and alias records pointing custom domain traffic to CloudFront.

```text
                  +-------------------+
                  |   Route 53 DNS    |
                  +---------+---------+
                            |
                            v
+------------------+   +----+-------------------+   +-------------------+
|  ACM Certificate |-->| CloudFront CDN         |-->| Private S3 Bucket |
|   (us-east-1)    |   | (Origin Access Control)|   | (/public prefix)  |
+------------------+   +------------------------+   +-------------------+
```

## Directory Structure

```text
static-website/
├── Architecture.md         # Detailed architectural, provisioning, and runtime specification
├── README.md               # Root repository documentation
├── assets/                 # Website static source files (index.html, error.html, etc.)
├── environment/
│   └── dev/                # Environment deployment configuration
│       ├── main.tf         # Main Terraform orchestration file
│       ├── locals.tf       # Local variables and helpers
│       ├── variables.tf    # Input variables declarations
│       ├── outputs.tf      # Deployment outputs
│       └── terraform.tfvars# Environment configuration values
└── modules/                # Reusable Terraform infrastructure modules
    ├── acm/                # AWS Certificate Manager module (us-east-1 provider)
    ├── cloudfront/         # AWS CloudFront CDN distribution module
    ├── route53/            # AWS Route 53 DNS records module
    └── s3-bucket/          # AWS S3 bucket and object upload module
```

## Modules Summary

- [`modules/acm`](modules/acm/README.md): Provisions ACM SSL/TLS certificates in `us-east-1` and waits for DNS validation.
- [`modules/cloudfront`](modules/cloudfront/README.md): Deploys CloudFront distribution with custom error handling (`/error.html`) and Origin Access Control.
- [`modules/route53`](modules/route53/README.md): Manages Route 53 DNS validation CNAME records (`allow_overwrite = true`) and domain A alias records.
- [`modules/s3-bucket`](modules/s3-bucket/README.md): Configures private S3 bucket, uploads website assets to `/public/`, and applies CloudFront OAC bucket policy.

## Deployment Instructions

### Prerequisites
- [Terraform](https://www.terraform.io/downloads.html) >= 1.0.0
- AWS CLI configured with appropriate credentials.

### Deploying the Environment

1. Navigate to the desired environment directory:
   ```bash
   cd environment/dev
   ```

2. Initialize Terraform modules and providers:
   ```bash
   terraform init
   ```

3. Review the execution plan:
   ```bash
   terraform plan
   ```

4. Apply the configuration:
   ```bash
   terraform apply
   ```

> **Note**: CloudFront requires ACM certificates to reside in the `us-east-1` region. The `acm` module uses an aliased provider `providers = { aws = aws.us_east_1 }` to enforce `us-east-1` certificate creation.
