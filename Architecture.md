# Static Website Architecture & Infrastructure Technical Specification

This document provides a comprehensive technical breakdown of the infrastructure-as-code architecture for hosting a secure, high-performance static website on AWS S3 and CloudFront using Terraform.

---

## 1. System Overview & Security Principles

The static website hosting platform is designed around four core architectural principles:

1. **Zero Direct Public S3 Access**: The S3 bucket blocks all public ACLs and bucket policies (`aws_s3_bucket_public_access_block`). All incoming traffic must flow through Amazon CloudFront.
2. **Origin Access Control (OAC)**: S3 objects are secured using AWS SigV4 request signing. S3 Bucket Policy grants `s3:GetObject` permission strictly to the CloudFront distribution via an `AWS:SourceArn` condition.
3. **Global Edge Acceleration with Custom SSL**: Website content is cached and distributed across AWS CloudFront edge locations worldwide. Connections use HTTPS via an AWS Certificate Manager (ACM) certificate issued in `us-east-1` with modern TLS 1.2+ encryption protocols.
4. **Dynamic DNS Management**: AWS Route 53 handles domain routing with Alias A records and dynamically provisions DNS validation CNAME records for automated ACM SSL issuance.

---

## 2. End-to-End System Architecture

```text
[ User Client ]
       │
       │  1. HTTPS Request (https://namecheap-test.me)
       v
+-------------------------------------------------------------------------------+
| Route 53 Hosted Zone                                                          |
|  ├── A Record Alias ───────────► Points to CloudFront Distribution Endpoint   |
|  └── CNAME Records ────────────► ACM DNS Validation Records                   |
+-------------------------------------------------------------------------------+
       │
       v
+-------------------------------------------------------------------------------+
| CloudFront CDN Distribution                                                   |
|  ├── Custom Domain Alias        : namecheap-test.me                            |
|  ├── Viewer Certificate         : ACM Certificate (us-east-1, TLS 1.2+)       |
|  ├── Custom Error Responses     : 403 / 404 ──► /error.html                  |
|  ├── Origin Path                : /public                                     |
|  └── Origin Access Control (OAC): SigV4 Signing                               |
+-------------------------------------------------------------------------------+
       │
       │  2. Authenticated Read Request (SigV4 Signed)
       v
+-------------------------------------------------------------------------------+
| S3 Storage Bucket (Private)                                                   |
|  ├── Public Access Block        : 100% Public Access Blocked                  |
|  ├── Default Encryption         : AES256 Server-Side Encryption               |
|  ├── Object Versioning          : Enabled                                     |
|  ├── Bucket Policy              : Allows CloudFront (AWS:SourceArn)           |
|  └── Storage Location           : s3://namecheap-test.me/public/*             |
+-------------------------------------------------------------------------------+
```

---

## 3. Module-by-Module Technical Deep Dive

```text
modules/
├── acm/          # SSL/TLS Certificate Provisioning (us-east-1)
├── cloudfront/   # Global CDN Distribution & OAC Configuration
├── route53/      # DNS Hosted Zone Queries & Record Provisioning
└── s3-bucket/    # Private Storage Bucket, Asset Uploads & OAC Policy
```

---

### Module 1: S3 Bucket (`modules/s3-bucket`)

The `s3-bucket` module provisions private S3 storage, manages static asset uploads from the local filesystem, and enforces CloudFront-only access permissions.

#### Resources Declared ([`modules/s3-bucket/main.tf`](file:///c:/Users/Vartotojas/project_aws/infra/deploy/static-website/modules/s3-bucket/main.tf))

- **`aws_s3_bucket.this`**:
  - Creates the bucket resource using `var.bucket_name`.
  - `force_destroy = true`: Enables Terraform to empty non-current object versions and delete markers when destroying the bucket.
  - Contains Checkov inline skips for dev/learning setup (`CKV_AWS_18`, `CKV_AWS_145`, `CKV_AWS_144`, `CKV2_AWS_62`, `CKV2_AWS_61`).
- **`aws_s3_bucket_public_access_block.this`**:
  - Sets `block_public_acls = true`, `block_public_policy = true`, `ignore_public_acls = true`, and `restrict_public_buckets = true`.
- **`aws_s3_bucket_server_side_encryption_configuration.this`**:
  - Configures default server-side encryption using AES256 (`apply_server_side_encryption_by_default { sse_algorithm = "AES256" }`).
- **`aws_s3_bucket_versioning.this`**:
  - Configures bucket versioning status to `Enabled`.
- **`aws_s3_bucket_website_configuration.this`**:
  - Sets `index_document` suffix to `index.html` and `error_document` key to `error.html`.
- **`aws_s3_object.website_files`**:
  - Scans local files in `assets/` recursively using `fileset(abspath("${path.module}/../../assets"), "**")`.
  - Uploads objects to `key = "public/${each.value}"`.
  - Computes `etag = filemd5(...)` to ensure objects are updated only when local file content changes.
  - Sets `content_type` using `lookup(var.mime_types, lower(regex("[^.]+$", each.value)), "application/octet-stream")`.
- **`aws_s3_bucket_policy.cloudfront_oac`**:
  - Attaches an S3 resource policy allowing `s3:GetObject` to `Principal = { Service = "cloudfront.amazonaws.com" }`.
  - Enforces access control using `Condition = { StringEquals = { "AWS:SourceArn" = var.cloudfront_distribution_arn } }` and scopes resource to `${aws_s3_bucket.this.arn}${var.origin_path}/*`.

#### Inputs ([`modules/s3-bucket/variables.tf`](file:///c:/Users/Vartotojas/project_aws/infra/deploy/static-website/modules/s3-bucket/variables.tf))
- `bucket_name` (`string`): S3 bucket name.
- `tags` (`map(string)`): Resource tags.
- `mime_types` (`map(string)`): Map of file extensions to HTTP Content-Type headers.
- `cloudfront_distribution_arn` (`string`): CloudFront ARN used in the bucket policy condition.
- `origin_path` (`string`): Path to the origin directory in S3 (e.g. `/public`).

#### Outputs ([`modules/s3-bucket/outputs.tf`](file:///c:/Users/Vartotojas/project_aws/infra/deploy/static-website/modules/s3-bucket/outputs.tf))
- `bucket_name`: Name of the bucket.
- `bucket_arn`: ARN of the bucket.
- `website_endpoint`: S3 website endpoint URL.
- `regional_domain_name`: Regional domain name (used as CloudFront origin domain).

---

### Module 2: CloudFront Distribution (`modules/cloudfront`)

The `cloudfront` module provisions the CDN distribution, configures Origin Access Control (OAC), attaches the SSL certificate, and maps custom error responses.

#### Resources Declared ([`modules/cloudfront/main.tf`](file:///c:/Users/Vartotojas/project_aws/infra/deploy/static-website/modules/cloudfront/main.tf))

- **`aws_cloudfront_distribution.this`**:
  - `enabled = true` & `is_ipv6_enabled = true`.
  - `default_root_object = var.default_root_object` (`index.html`).
  - `aliases = [var.domain_name]`: Maps custom domain CNAME aliases.
  - **`origin` Block**:
    - `domain_name = var.regional_domain_name`: Points to S3 bucket regional endpoint.
    - `origin_id = "s3-origin"`.
    - `origin_access_control_id = aws_cloudfront_origin_access_control.oac.id`: Enforces OAC authentication.
    - `origin_path = var.origin_path`: Routes root CDN requests to `/public` inside the S3 bucket.
  - **`default_cache_behavior` Block**:
    - `viewer_protocol_policy = "redirect-to-https"`: Forces HTTPS.
    - `allowed_methods = ["GET", "HEAD"]` & `cached_methods = ["GET", "HEAD"]`.
  - **`custom_error_response` Blocks**:
    - Custom error handling for HTTP `403` and `404` status codes, rendering `var.error_page_path` (`/error.html`) with `error_caching_min_ttl = 10`.
  - **`viewer_certificate` Block**:
    - `acm_certificate_arn = var.acm_certificate_arn`: Attaches the `us-east-1` ACM certificate.
    - `ssl_support_method = "sni-only"` & `minimum_protocol_version = "TLSv1.2_2021"`.
- **`aws_cloudfront_origin_access_control.oac`**:
  - `name = "s3-oac"`.
  - `origin_access_control_origin_type = "s3"`.
  - `signing_behavior = "always"`.
  - `signing_protocol = "sigv4"`.

#### Inputs ([`modules/cloudfront/variables.tf`](file:///c:/Users/Vartotojas/project_aws/infra/deploy/static-website/modules/cloudfront/variables.tf))
- `domain_name`, `acm_certificate_arn`, `regional_domain_name`, `origin_path`, `default_root_object`, `error_page_path`, `project`, `environment`, `tags`.

#### Outputs ([`modules/cloudfront/output.tf`](file:///c:/Users/Vartotojas/project_aws/infra/deploy/static-website/modules/cloudfront/output.tf))
- `cloudfront_distribution_domain_name`: CDN domain (e.g. `d123.cloudfront.net`).
- `cloudfront_distribution_hosted_zone_id`: CloudFront zone ID (`Z2FDTNDATAQYW2`).
- `cloudfront_distribution_arn`: Distribution ARN (passed into S3 bucket policy).

---

### Module 3: ACM Certificate (`modules/acm`)

The `acm` module requests public SSL/TLS certificates and blocks execution until DNS validation succeeds.

#### Resources Declared ([`modules/acm/main.tf`](file:///c:/Users/Vartotojas/project_aws/infra/deploy/static-website/modules/acm/main.tf))

- **`aws_acm_certificate.this`**:
  - Requests a certificate for `var.domain_name` with wildcard Subject Alternative Names (`*.${var.domain_name}`).
  - `validation_method = "DNS"`.
  - `lifecycle { create_before_destroy = true }`: Prevents cert replacement downtime.
- **`aws_acm_certificate_validation.this`**:
  - Takes `validation_record_fqdns = var.acm_validation_records_fqdns`.
  - Pauses execution until ACM detects the DNS records in Route 53 and marks status as `ISSUED`.

#### Inputs ([`modules/acm/variables.tf`](file:///c:/Users/Vartotojas/project_aws/infra/deploy/static-website/modules/acm/variables.tf))
- `domain_name`, `environment`, `acm_validation_records_fqdns`, `tags`.

#### Outputs ([`modules/acm/output.tf`](file:///c:/Users/Vartotojas/project_aws/infra/deploy/static-website/modules/acm/output.tf))
- `acm_certificate_arn`: ARN of the validated ACM certificate.
- `domain_validation_options`: Exported domain validation record parameters.

---

### Module 4: Route 53 DNS (`modules/route53`)

The `route53` module handles DNS lookup, alias record creation, and dynamic ACM validation CNAME record management.

#### Data Sources & Resources ([`modules/route53/main.tf`](file:///c:/Users/Vartotojas/project_aws/infra/deploy/static-website/modules/route53/main.tf))

- **`data.aws_route53_zone.main`**:
  - Queries AWS for the existing Route 53 Hosted Zone matching `var.domain_name`.
- **`aws_route53_record.root`**:
  - Provisions an `A` record alias for the apex domain pointing to `var.cloudfront_distribution_domain_name` and `var.cloudfront_distribution_hosted_zone_id`.
- **`aws_route53_record.acm_validation`**:
  - Iterates using `for_each = toset(var.validation_domains)` (`["domain.com", "*.domain.com"]`).
  - Dynamically extracts CNAME record parameters from `var.domain_validation_options` using list comprehensions:
    ```hcl
    name = [
      for dvo in var.domain_validation_options : dvo.resource_record_name
      if dvo.domain_name == each.value
    ][0]
    ```

#### Inputs ([`modules/route53/variable.tf`](file:///c:/Users/Vartotojas/project_aws/infra/deploy/static-website/modules/route53/variable.tf))
- `domain_name`, `domain_validation_options`, `cloudfront_distribution_domain_name`, `cloudfront_distribution_hosted_zone_id`, `validation_domains`.

#### Outputs ([`modules/route53/output.tf`](file:///c:/Users/Vartotojas/project_aws/infra/deploy/static-website/modules/route53/output.tf))
- `route53_zone_id` & `route53_zone_name`: Route 53 zone metadata.
- `validation_record_fqdns`: List of FQDNs for ACM validation records.

---

## 4. Inter-Module Dependency & Data-Flow Graph

The root environment layer ([`environment/dev/main.tf`](file:///c:/Users/Vartotojas/project_aws/infra/deploy/static-website/environment/dev/main.tf) and [`environment/dev/locals.tf`](file:///c:/Users/Vartotojas/project_aws/infra/deploy/static-website/environment/dev/locals.tf)) coordinates data flow across modules:

```text
1. module.acm (Domain Request)
       │
       ▼  (exports domain_validation_options)
2. module.route53 (Creates DNS CNAME Validation Records)
       │
       ▼  (exports validation_record_fqdns)
3. module.acm (aws_acm_certificate_validation waits for ISSUED status)
       │
       ▼  (exports acm_certificate_arn)
4. module.cloudfront (Creates CDN Distribution with US-East-1 SSL & OAC)
       │
       ├──────────────────────────────────────────┐
       ▼ (exports cloudfront_distribution_arn)    ▼ (exports distribution_domain_name)
5. module.s3_bucket                      6. module.route53
   (Attaches OAC Bucket Policy)             (Creates Alias A Record to CDN)
```

### Provider Aliasing for CloudFront Certificates
CloudFront strictly requires ACM certificates to reside in `us-east-1`. In [`environment/dev/main.tf`](file:///c:/Users/Vartotojas/project_aws/infra/deploy/static-website/environment/dev/main.tf#L16-L19):
```hcl
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

module "acm" {
  source    = "../../modules/acm"
  providers = { aws = aws.us_east_1 } # Directs ACM module to us-east-1
  ...
}
```

---

## 5. CI/CD Security & Automation Pipeline

Continuous Integration is managed via GitHub Actions in [`.github/workflows/terraform-ci.yml`](file:///c:/Users/Vartotojas/project_aws/infra/deploy/static-website/.github/workflows/terraform-ci.yml):

1. **Format & Validation**: Runs `terraform fmt -check` and `terraform validate`.
2. **Checkov Security Scan**: Runs `bridgecrewio/checkov-action@v12` to scan Terraform code for security compliance and exports `checkov-results.sarif`.
3. **Trivy SAST Scan**: Runs `aquasecurity/trivy-action@v0.36.0` to scan filesystem for vulnerabilities/misconfigurations and exports `trivy-sast-results.sarif`.
4. **SARIF-to-Markdown Summary**: Uses `b-zurg/sarif-to-markdown@v1` (`add-job-summary: true`) to render interactive security summaries directly in the GitHub Actions Workflow Run window.
5. **Artifact Uploads**: Archives `checkov-security-report` and `trivy-sast-report` as downloadable run artifacts.

---

## 6. Local Operational Commands

### Environment Deployment
```powershell
cd environment/dev
terraform init
terraform plan
terraform apply
```

### Forcing Certificate / Resource Replacement
```powershell
terraform apply -replace="module.acm.aws_acm_certificate.this"
```
