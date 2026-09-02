# Infrastructure Architecture & Under-the-Hood Operations

This document explains how the static website hosting architecture is built, how the Terraform modules connect, and the complete flow of operation from infrastructure provisioning to runtime user requests.

---

## 1. Architectural Overview & Security Model

The infrastructure is designed for high performance, zero-trust storage security, and global scalability:

- **Private S3 Bucket**: Stores static assets under the `/public` prefix. Public access is 100% blocked (`aws_s3_bucket_public_access_block`). Direct HTTP access to S3 returns `403 Forbidden`.
- **CloudFront CDN**: Acts as the single entry point. Content is cached at edge locations worldwide. Authenticates requests to S3 using **Origin Access Control (OAC)** with SigV4 signing.
- **ACM SSL Certificate**: Provides HTTPS encryption. Issued in the **`us-east-1` (N. Virginia)** region (a mandatory CloudFront requirement) and validated automatically via DNS.
- **Route 53 DNS**: Manages domain resolution using **Alias A records** for zero-latency CDN routing and provisions CNAME records for ACM validation.

---

## 2. Infrastructure Provisioning Flow (Terraform Order of Operation)

Terraform orchestrates resource creation through an automated dependency graph across four modules:

```text
1. module.s3_bucket ──► Creates Private S3 Bucket & Uploads Assets to /public
2. module.acm       ──► Requests SSL Certificate in us-east-1 (DNS Validation)
3. module.route53   ──► Creates CNAME Validation Records in Route 53 (allow_overwrite = true)
4. module.acm       ──► aws_acm_certificate_validation Waits Until Certificate Status is ISSUED
5. module.cloudfront ──► Provisions CDN Distribution with OAC, us-east-1 SSL Cert & origin_path = "/public"
6. module.s3_bucket ──► Attaches Bucket Policy Locking s3:GetObject to CloudFront AWS:SourceArn
7. module.route53   ──► Creates Apex Domain Alias A Record Pointing to CloudFront Endpoint
```

### Detailed Provisioning Sequence

1. **S3 Bucket Setup (`modules/s3-bucket`)**:
   - Creates `aws_s3_bucket.this` with AES256 server-side encryption.
   - Applies `aws_s3_bucket_public_access_block.this` to reject all public access.
   - Uploads static website files from local `assets/` directory to S3 key prefix `public/` (e.g. `public/index.html`, `public/error.html`).

2. **ACM Certificate Request (`modules/acm`)**:
   - Requests a public SSL certificate in `us-east-1` via an aliased provider (`providers = { aws = aws.us_east_1 }`) for the domain (`namecheap-test.me`) and wildcard (`*.namecheap-test.me`).
   - ACM generates DNS validation CNAME tokens (`domain_validation_options`).

3. **Route 53 CNAME Validation Records (`modules/route53`)**:
   - Reads `domain_validation_options` from `module.acm`.
   - Provisions CNAME validation records in the Route 53 Hosted Zone using `for_each`.
   - Uses `allow_overwrite = true` so Route 53 safely updates overlapping validation records when root and wildcard domains share validation tokens.

4. **Certificate Validation Synchronization Gateway (`modules/acm`)**:
   - `aws_acm_certificate_validation.this` takes the CNAME FQDNs created by Route 53.
   - **Blocks Terraform execution** until AWS ACM queries Route 53, verifies DNS ownership, and sets status to `ISSUED`.

5. **CloudFront CDN Distribution (`modules/cloudfront`)**:
   - Created only *after* the SSL certificate is `ISSUED`.
   - Configures Origin Access Control (`aws_cloudfront_origin_access_control.oac`) using SigV4 signing.
   - Binds custom domain alias (`aliases = [var.domain_name]`), attaches the validated `us-east-1` ACM certificate (`TLSv1.2_2021`), and sets `origin_path = "/public"`.
   - Configures custom error responses mapping HTTP 403 & 404 to `/error.html`.

6. **S3 OAC Bucket Policy Attachment (`modules/s3-bucket`)**:
   - Receives `cloudfront_distribution_arn` from `module.cloudfront`.
   - Attaches `aws_s3_bucket_policy.cloudfront_oac` granting `s3:GetObject` on `arn:aws:s3:::bucket/public/*` strictly when `AWS:SourceArn` matches the CloudFront distribution ARN.

7. **Route 53 Alias Record (`modules/route53`)**:
   - Receives `cloudfront_distribution_domain_name` (e.g., `d1234.cloudfront.net`).
   - Provisions an `A` record Alias pointing domain traffic (`namecheap-test.me`) to CloudFront.

---

## 3. Runtime Request Flow of Operation

```text
[ User Browser ]
       │
       │  1. Visitor opens https://namecheap-test.me
       v
+-------------------------------------------------------------------------------+
| Route 53 DNS                                                                  |
|  └── Resolves apex A record directly to CloudFront global edge IP addresses  |
+-------------------------------------------------------------------------------+
       │
       v
+-------------------------------------------------------------------------------+
| CloudFront CDN Edge PoP                                                       |
|  ├── Performs TLS 1.2+ HTTPS handshake using ACM Certificate                  |
|  ├── Checks Edge Cache:                                                       |
|  │    ├── CACHE HIT  ──► Delivers cached static content immediately (200 OK)  |
|  │    └── CACHE MISS ──► Signs request with SigV4 OAC & appends /public       |
+-------------------------------------------------------------------------------+
       │
       │  2. Authenticated Read Request (SigV4 Signed for /public/index.html)
       v
+-------------------------------------------------------------------------------+
| Private S3 Bucket                                                             |
|  ├── Evaluates Bucket Policy: Does AWS:SourceArn match CloudFront ARN?        |
|  │    ├── MATCH    ──► Returns object content (s3://bucket/public/index.html) |
|  │    └── MISMATCH ──► 403 Forbidden                                          |
+-------------------------------------------------------------------------------+
       │
       │  3. Object delivered to CloudFront Edge (Cached for subsequent visitors)
       v
[ User Browser renders website ]
```

---

## 4. Key Implementation Details & Technical Gotchas

- **Why `us-east-1` for ACM?**: CloudFront is a global edge service. AWS requires all SSL/TLS certificates attached to CloudFront distributions to be created in the `us-east-1` (N. Virginia) region, regardless of where your primary S3 bucket or Route 53 zone resides.
- **Why `allow_overwrite = true` in Route 53?**: When requesting a certificate for both `example.com` and `*.example.com`, ACM often generates identical CNAME validation tokens. `allow_overwrite = true` prevents Route 53 from throwing duplicate record errors during Terraform apply.
- **Explicit Synchronization via `aws_acm_certificate_validation`**: Acts as an explicit dependency barrier. CloudFront cannot be provisioned with an unvalidated certificate; Terraform holds execution until ACM marks the certificate status as `ISSUED`.
- **Origin Path Isolation (`origin_path = "/public"`)**: Web visitors request `https://example.com/index.html`, but CloudFront internally queries `s3://bucket/public/index.html`. This isolates asset files inside a clean directory prefix.
