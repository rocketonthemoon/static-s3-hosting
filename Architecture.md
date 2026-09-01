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

The `s3-bucket` module is responsible for private object storage, versioning, default server-side encryption, uploading local website assets, and applying the CloudFront Origin Access Control (OAC) bucket policy.

#### 1. Input Parameters with Example Values

| Input Parameter | Type | Real Example Value | Purpose & Explanation |
|---|---|---|---|
| `bucket_name` | `string` | `"namecheap-test.me"` | Globally unique AWS S3 bucket name. Must match the domain name. |
| `origin_path` | `string` | `"/public"` | Sub-folder path inside the bucket where web assets are stored and fetched. |
| `cloudfront_distribution_arn` | `string` | `"arn:aws:cloudfront::123456789012:distribution/E1A2B3C4D5E6F7"` | ARN of the CloudFront CDN allowed to read objects via OAC. |
| `mime_types` | `map(string)` | `{ "html" = "text/html", "css" = "text/css", "js" = "application/javascript" }` | Map of file extensions to HTTP `Content-Type` headers. |
| `tags` | `map(string)` | `{ Environment = "dev", Project = "static-hosting", ManagedBy = "terraform" }` | Metadata tags attached to AWS S3 resources. |

#### 2. Detailed Resource Mechanics & HCL Behavior

- **`aws_s3_bucket.this`**:
  - Provisions the bucket `namecheap-test.me` in `eu-north-1`.
  - `force_destroy = true`: Instructs Terraform to automatically delete non-current object versions and delete markers when tearing down the environment.
- **`aws_s3_bucket_public_access_block.this`**:
  - Sets `block_public_acls = true`, `block_public_policy = true`, `ignore_public_acls = true`, and `restrict_public_buckets = true`.
  - **Security Result**: The bucket rejects 100% of direct unauthenticated public HTTP GET requests (`403 Forbidden`).
- **`aws_s3_bucket_server_side_encryption_configuration.this`**:
  - Applies default AES256 server-side encryption (`sse_algorithm = "AES256"`). All uploaded objects are encrypted transparently at rest.
- **`aws_s3_bucket_versioning.this`**:
  - Enables bucket versioning (`status = "Enabled"`). Every file modification or upload preserves previous revisions.
- **`aws_s3_bucket_website_configuration.this`**:
  - Defines `index_document { suffix = "index.html" }` and `error_document { key = "error.html" }`.
- **`aws_s3_object.website_files`**:
  - Scans local directory `assets/` recursively using `fileset(abspath("${path.module}/../../assets"), "**")`.
  - Iterates over files and uploads them into S3 under `key = "public/${each.value}"`:
    - `assets/index.html` ➔ S3 object `key = "public/index.html"` (`Content-Type: text/html`, `etag = "a1b2c3d4..."`).
    - `assets/error.html` ➔ S3 object `key = "public/error.html"` (`Content-Type: text/html`, `etag = "e5f6g7h8..."`).
  - `etag = filemd5(...)`: Calculates MD5 checksums of local files. Terraform re-uploads objects *only* when local file contents change.
- **`aws_s3_bucket_policy.cloudfront_oac`**:
  - Generates and attaches the resource policy JSON:
    ```json
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Sid": "AllowCloudFrontServicePrincipalReadOnly",
          "Effect": "Allow",
          "Principal": { "Service": "cloudfront.amazonaws.com" },
          "Action": "s3:GetObject",
          "Resource": "arn:aws:s3:::namecheap-test.me/public/*",
          "Condition": {
            "StringEquals": {
              "AWS:SourceArn": "arn:aws:cloudfront::123456789012:distribution/E1A2B3C4D5E6F7"
            }
          }
        }
      ]
    }
    ```

#### 3. Output Parameters with Exported Values

| Output Name | Exported Example Value | Target Consumer / Usage |
|---|---|---|
| `bucket_name` | `"namecheap-test.me"` | Environment state reference. |
| `bucket_arn` | `"arn:aws:s3:::namecheap-test.me"` | Environment state reference. |
| `regional_domain_name` | `"namecheap-test.me.s3.eu-north-1.amazonaws.com"` | Passed to `module.cloudfront` as `var.regional_domain_name` to route origin queries directly to `eu-north-1` without cross-region DNS hops. |

---

### Module 2: CloudFront CDN Distribution (`modules/cloudfront`)

The `cloudfront` module provisions the global edge acceleration layer, attaches the SSL certificate, enforces HTTPS, routes requests to S3 `/public`, and configures Origin Access Control (OAC).

#### 1. Input Parameters with Example Values

| Input Parameter | Type | Real Example Value | Purpose & Explanation |
|---|---|---|---|
| `domain_name` | `string` | `"namecheap-test.me"` | Custom domain name mapped as a CNAME alias. |
| `acm_certificate_arn` | `string` | `"arn:aws:acm:us-east-1:123456789012:certificate/a1b2c3d4-5678-90ab-cdef-1234567890ab"` | SSL certificate ARN issued in `us-east-1`. |
| `regional_domain_name` | `string` | `"namecheap-test.me.s3.eu-north-1.amazonaws.com"` | Regional endpoint of the S3 bucket origin. |
| `origin_path` | `string` | `"/public"` | Directs CloudFront origin requests to `/public`. |
| `default_root_object` | `string` | `"index.html"` | Default object returned for root URL requests (`/`). |
| `error_page_path` | `string` | `"/error.html"` | Custom error document path served for 403 & 404. |

#### 2. Detailed Resource Mechanics & HCL Behavior

- **`aws_cloudfront_origin_access_control.oac`**:
  - Creates OAC resource `E3P1234567890` with `signing_protocol = "sigv4"` and `signing_behavior = "always"`.
  - When CloudFront fetches objects from S3, it computes and attaches SigV4 headers (`Authorization`, `X-Amz-Content-Sha256`, `X-Amz-Date`).
- **`aws_cloudfront_distribution.this`**:
  - **Distribution Domain**: Assigns global CDN domain `d111111abcdef8.cloudfront.net`.
  - **Custom CNAME Alias**: Binds `aliases = ["namecheap-test.me"]`. Requests sending `Host: namecheap-test.me` are accepted by the edge.
  - **Origin Path Routing (`/public`)**: Maps origin `namecheap-test.me.s3.eu-north-1.amazonaws.com` with `origin_path = "/public"`. Client request `https://namecheap-test.me/index.html` ➔ CloudFront origin fetch `s3://namecheap-test.me/public/index.html`.
  - **Viewer Certificate**: Attaches `acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/..."` with `ssl_support_method = "sni-only"` and `minimum_protocol_version = "TLSv1.2_2021"`. Disables insecure SSLv3/TLS 1.0/1.1 protocols.
  - **HTTPS Enforcement**: `viewer_protocol_policy = "redirect-to-https"`. All unencrypted HTTP requests (port 80) receive a `301 Moved Permanently` redirect to HTTPS (port 443).
  - **Custom Error Response Handling**: Intercepts origin 403 Forbidden and 404 Not Found status codes and renders `/error.html` with `error_caching_min_ttl = 10` seconds.

#### 3. Output Parameters with Exported Values

| Output Name | Exported Example Value | Target Consumer / Usage |
|---|---|---|
| `cloudfront_distribution_domain_name` | `"d111111abcdef8.cloudfront.net"` | Passed to `module.route53` for the apex `A` Alias record. |
| `cloudfront_distribution_hosted_zone_id` | `"Z2FDTNDATAQYW2"` | Passed to `module.route53` (global CloudFront hosted zone ID). |
| `cloudfront_distribution_arn` | `"arn:aws:cloudfront::123456789012:distribution/E1A2B3C4D5E6F7"` | Passed to `module.s3_bucket` for the S3 OAC bucket policy condition. |

---

### Module 3: ACM Certificate (`modules/acm`)

The `acm` module requests public SSL/TLS certificates in `us-east-1` and blocks execution until DNS validation completes.

#### 1. Input Parameters with Example Values

| Input Parameter | Type | Real Example Value | Purpose & Explanation |
|---|---|---|---|
| `domain_name` | `string` | `"namecheap-test.me"` | Primary domain name for the certificate. |
| `environment` | `string` | `"dev"` | Environment tag value. |
| `acm_validation_records_fqdns` | `list(string)` | `["_a1b2c3d4e5f6.namecheap-test.me", "_x1y2z3a4b5c6.namecheap-test.me"]` | List of DNS CNAME FQDNs created by Route 53. |

#### 2. Detailed Resource Mechanics & HCL Behavior

- **`aws_acm_certificate.this`**:
  - Initiates certificate request targeting `namecheap-test.me` with `subject_alternative_names = ["*.namecheap-test.me"]`.
  - Enforces `validation_method = "DNS"`.
  - `lifecycle { create_before_destroy = true }`: Prevents downtime during certificate renewals.
  - Exports `domain_validation_options`:
    - Option 1 (`namecheap-test.me`): Name `_a1b2c3d4e5f6.namecheap-test.me.`, Value `_x1y2z3.acm-validations.aws.`, Type `CNAME`.
    - Option 2 (`*.namecheap-test.me`): Name `_x1y2z3a4b5c6.namecheap-test.me.`, Value `_x1y2z3.acm-validations.aws.`, Type `CNAME`.
- **`aws_acm_certificate_validation.this`**:
  - Monitors Route 53 CNAME validation records (`_a1b2c3d4e5f6.namecheap-test.me` and `_x1y2z3a4b5c6.namecheap-test.me`).
  - Holds Terraform in a blocking state until ACM verifies DNS ownership and sets certificate status to `ISSUED`.

#### 3. Output Parameters with Exported Values

| Output Name | Exported Example Value | Target Consumer / Usage |
|---|---|---|
| `acm_certificate_arn` | `"arn:aws:acm:us-east-1:123456789012:certificate/a1b2c3d4-5678-90ab-cdef-1234567890ab"` | Passed to `module.cloudfront` as `var.acm_certificate_arn`. |
| `domain_validation_options` | `[ { domain_name = "namecheap-test.me", resource_record_name = "_a1b2c3...", ... } ]` | Passed to `module.route53` to create DNS validation records. |

---

### Module 4: Route 53 DNS (`modules/route53`)

The `route53` module handles DNS lookup, alias record creation, and dynamic ACM validation CNAME record management.

#### 1. Input Parameters with Example Values

| Input Parameter | Type | Real Example Value | Purpose & Explanation |
|---|---|---|---|
| `domain_name` | `string` | `"namecheap-test.me"` | Apex domain name to query in Route 53. |
| `cloudfront_distribution_domain_name` | `string` | `"d111111abcdef8.cloudfront.net"` | Target CloudFront domain for Alias A record. |
| `cloudfront_distribution_hosted_zone_id` | `string` | `"Z2FDTNDATAQYW2"` | Hosted zone ID of CloudFront (`Z2FDTNDATAQYW2`). |
| `validation_domains` | `list(string)` | `["namecheap-test.me", "*.namecheap-test.me"]` | Domain names requiring DNS validation CNAME records. |
| `domain_validation_options` | `list(any)` | Exported options list from `module.acm` | Contains CNAME names, types, and values. |

#### 2. Detailed Resource Mechanics & HCL Behavior

- **`data.aws_route53_zone.main`**:
  - Queries AWS for the pre-existing Route 53 Hosted Zone matching `namecheap-test.me` (discovers ID `Z0123456789ABCDEF`).
- **`aws_route53_record.acm_validation`**:
  - Iterates using `for_each = toset(["namecheap-test.me", "*.namecheap-test.me"])`.
  - Uses list comprehensions to extract matching CNAME records:
    - Creates CNAME record `_a1b2c3d4e5f6.namecheap-test.me` ➔ `_x1y2z3.acm-validations.aws.` (TTL 60).
    - Creates CNAME record `_x1y2z3a4b5c6.namecheap-test.me` ➔ `_x1y2z3.acm-validations.aws.` (TTL 60).
- **`aws_route53_record.root`**:
  - Provisions apex domain IPv4 `A` Alias record: `namecheap-test.me` ➔ `d111111abcdef8.cloudfront.net` (Zone `Z2FDTNDATAQYW2`).
  - `evaluate_target_health = false`: Routes traffic to CloudFront edge locations without health check overhead.

#### 3. Output Parameters with Exported Values

| Output Name | Exported Example Value | Target Consumer / Usage |
|---|---|---|
| `route53_zone_id` | `"Z0123456789ABCDEF"` | Route 53 zone ID reference. |
| `route53_zone_name` | `"namecheap-test.me"` | Route 53 zone name reference. |
| `validation_record_fqdns` | `["_a1b2c3d4e5f6.namecheap-test.me", "_x1y2z3a4b5c6.namecheap-test.me"]` | Passed to `module.acm` as `acm_validation_records_fqdns`. |

---

## 4. Inter-Module Integration & Data-Flow Lifecycle

The root environment layer ([`environment/dev/main.tf`]) and ([`environment/dev/locals.tf`]) orchestrates how all four modules connect into a unified, secure platform:

```text
1. module.acm (Domain Certificate Request)
       │
       ▼  (exports domain_validation_options)
2. module.route53 (Creates DNS CNAME Validation Records in Route 53)
       │
       ▼  (exports validation_record_fqdns)
3. module.acm (aws_acm_certificate_validation blocks until ISSUED)
       │
       ▼  (exports acm_certificate_arn)
4. module.cloudfront (Creates CDN Distribution with US-East-1 SSL & OAC)
       │
       ├──────────────────────────────────────────┐
       ▼ (exports cloudfront_distribution_arn)    ▼ (exports distribution_domain_name)
5. module.s3_bucket                      6. module.route53
   (Applies CloudFront OAC Bucket Policy)    (Creates Apex Domain Alias A Record)
```

---

### Comprehensive Inter-Module Wiring Matrix

| Link # | Source Module & Exported Output | Intermediate Local Variable in [`locals.tf`] | Target Module & Received Input | Real Example Data Flowing Across |
|---|---|---|---|---|
| **1** | `module.acm.domain_validation_options` | `local.acm_validation_options` | `module.route53.domain_validation_options` | Exports CNAME validation list `[ { resource_record_name = "_a1b2c3.namecheap-test.me.", resource_record_value = "_x1y2z3.acm-validations.aws." } ]` |
| **2** | `module.route53.validation_record_fqdns` | `local.acm_validation_records_fqdns` | `module.acm.acm_validation_records_fqdns` | Passes created CNAME FQDN list `["_a1b2c3.namecheap-test.me"]` back to ACM to wait for certificate status `ISSUED`. |
| **3** | `module.acm.acm_certificate_arn` | `local.acm_certificate_arn` | `module.cloudfront.acm_certificate_arn` | Passes validated SSL cert ARN `"arn:aws:acm:us-east-1:123456789012:certificate/a1b2c3d4-..."` in `us-east-1` to CloudFront. |
| **4** | `module.s3_bucket.regional_domain_name` | `local.s3_regional_domain_name` | `module.cloudfront.regional_domain_name` | Passes S3 regional endpoint `"namecheap-test.me.s3.eu-north-1.amazonaws.com"` to set CloudFront CDN origin domain. |
| **5** | `module.cloudfront.cloudfront_distribution_arn` | `local.cloudfront_distribution_arn` | `module.s3_bucket.cloudfront_distribution_arn` | Passes CloudFront ARN `"arn:aws:cloudfront::123456789012:distribution/E1A2B3C4D5E6F7"` to write S3 OAC policy `AWS:SourceArn` condition. |
| **6** | `module.cloudfront.cloudfront_distribution_domain_name` | `local.cloudfront_distribution_domain_name` | `module.route53.cloudfront_distribution_domain_name` | Passes CDN domain `"d111111abcdef8.cloudfront.net"` to Route 53 to point apex `A` Alias record. |
| **7** | `module.cloudfront.cloudfront_distribution_hosted_zone_id` | `local.cloudfront_distribution_hosted_zone_id` | `module.route53.cloudfront_distribution_hosted_zone_id` | Passes CloudFront Hosted Zone ID `"Z2FDTNDATAQYW2"` to Route 53 to complete alias target mapping. |

---

### Complete Step-by-Step Integration Assembly Sequence

#### Phase 1: SSL Certificate Request (`module.acm`)
- `environment/dev/main.tf` passes `providers = { aws = aws.us_east_1 }` to `module.acm` because CloudFront strictly requires ACM SSL certificates to originate in `us-east-1`.
- `module.acm` requests a public certificate for `var.domain_name` (`"namecheap-test.me"`) and wildcard (`"*.namecheap-test.me"`) with `validation_method = "DNS"`.
- AWS ACM generates DNS validation parameters and exports `domain_validation_options`:
  - Token 1: `_a1b2c3d4e5f6.namecheap-test.me.` ➔ `_x1y2z3.acm-validations.aws.`
  - Token 2: `_x1y2z3a4b5c6.namecheap-test.me.` ➔ `_x1y2z3.acm-validations.aws.`

#### Phase 2: Automated DNS Validation Record Creation (`module.route53`)
- `environment/dev/locals.tf` captures `acm_validation_options = module.acm.domain_validation_options` and passes it to `module.route53`.
- `module.route53` queries the existing Hosted Zone via `data.aws_route53_zone.main` (discovers zone `Z0123456789ABCDEF`).
- `aws_route53_record.acm_validation` iterates over `validation_domains` (`["namecheap-test.me", "*.namecheap-test.me"]`) using `for_each` and HCL list comprehensions to dynamically create DNS CNAME records in Route 53 pointing to AWS validation servers (`_a1b2c3d4e5f6.namecheap-test.me` ➔ `_x1y2z3.acm-validations.aws.`).

#### Phase 3: Certificate Issuance Synchronization (`module.acm` Validation Step)
- `module.route53` exports `validation_record_fqdns` (`["_a1b2c3d4e5f6.namecheap-test.me", "_x1y2z3a4b5c6.namecheap-test.me"]`).
- `environment/dev/locals.tf` passes `acm_validation_records_fqdns` back to `module.acm`.
- `aws_acm_certificate_validation.this` holds Terraform execution in a blocking wait state until AWS ACM queries Route 53, verifies CNAME propagation, and transitions certificate status to `ISSUED` (`arn:aws:acm:us-east-1:123456789012:certificate/a1b2c3d4-5678-90ab-cdef-1234567890ab`).

#### Phase 4: CloudFront CDN Distribution Provisioning (`module.cloudfront`)
- Once the certificate is `ISSUED`, `module.acm` exports `acm_certificate_arn`.
- `module.cloudfront` builds `aws_cloudfront_distribution.this` and `aws_cloudfront_origin_access_control.oac`:
  - Attaches `acm_certificate_arn` using SNI (`ssl_support_method = "sni-only"`).
  - Binds custom domain alias (`aliases = ["namecheap-test.me"]`).
  - Sets `origin_domain_name = "namecheap-test.me.s3.eu-north-1.amazonaws.com"` and `origin_path = "/public"` to direct origin requests into S3's `public/` directory.
  - Maps custom error responses (403 & 404 ➔ `/error.html`).
- CloudFront exports `cloudfront_distribution_arn` (`arn:aws:cloudfront::123456789012:distribution/E1A2B3C4D5E6F7`) and `cloudfront_distribution_domain_name` (`d111111abcdef8.cloudfront.net`).

#### Phase 5: S3 Private Storage & OAC Security Locking (`module.s3_bucket`)
- `module.s3_bucket` creates `aws_s3_bucket.this` (`namecheap-test.me`), enables encryption and versioning, and uploads local `assets/` files into `key = "public/${each.value}"` (`public/index.html`, `public/error.html`).
- `local.cloudfront_distribution_arn` (`arn:aws:cloudfront::123456789012:distribution/E1A2B3C4D5E6F7`) is passed to `module.s3_bucket`.
- `aws_s3_bucket_policy.cloudfront_oac` attaches the S3 Bucket Policy allowing `s3:GetObject` on `arn:aws:s3:::namecheap-test.me/public/*` strictly when `AWS:SourceArn == "arn:aws:cloudfront::123456789012:distribution/E1A2B3C4D5E6F7"`.
- **Result**: Direct HTTP access to S3 is blocked (`403 Forbidden`). S3 accepts requests *only* when signed by CloudFront's SigV4 OAC.

#### Phase 6: Apex Domain Route 53 Alias Routing (`module.route53`)
- `local.cloudfront_distribution_domain_name` (`d111111abcdef8.cloudfront.net`) and `local.cloudfront_distribution_hosted_zone_id` (`Z2FDTNDATAQYW2`) are passed to `module.route53`.
- `aws_route53_record.root` creates an IPv4 `A` Alias record `namecheap-test.me` ➔ `d111111abcdef8.cloudfront.net`.
- Route 53 routes domain queries (`https://namecheap-test.me`) directly to CloudFront's global edge IPs without incurring DNS query charges.

---

### Step-by-Step Runtime Request Execution Lifecycle

```text
[ Browser ] ──(1. DNS Lookup)──► [ Route 53 ] ──(Returns CloudFront IP)──► [ Browser ]
     │
     │  2. HTTPS Request (https://namecheap-test.me/index.html)
     v
[ CloudFront Edge PoP ]
     │
     ├──► (3. Cache Hit?) ──► Returns Cached Object (200 OK)
     │
     └──► (4. Cache Miss)
               │
               │  5. SigV4 Signed Request + Origin Path (/public/index.html)
               v
          [ Private S3 Bucket ]
               │
               ├──► 6. Policy Check: Matches AWS:SourceArn?
               │        ├── NO  ──► 403 Forbidden
               │        └── YES ──► 200 OK (Returns s3://bucket/public/index.html)
               │
               v
          [ CloudFront Edge PoP ] ──(Caches & Delivers)──► [ Browser ]
```

---

### Provider Aliasing for CloudFront Certificates
CloudFront strictly requires ACM certificates to reside in `us-east-1`. In [`environment/dev/main.tf`]:
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

Continuous Integration is managed via GitHub Actions in [`.github/workflows/terraform-ci.yml`]:

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
