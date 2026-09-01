locals {

  # Common tags for all resources
  common_tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }

  # S3 bucket name
  bucket_name = var.domain_name

  # S3 bucket website endpoint
  website_endpoint = module.s3_bucket.website_endpoint

  # Route53 zone ID
  route53_zone_id = module.route53.route53_zone_id

  # ACM certificate ARN
  acm_certificate_arn = module.acm.acm_certificate_arn

  # ACM validation options
  acm_validation_options = module.acm.domain_validation_options

  #ACM validation records FQDN list
  acm_validation_records_fqdns = module.route53.validation_record_fqdns

  # S3 regional domain name
  s3_regional_domain_name = module.s3_bucket.regional_domain_name

  # CloudFront distribution domain name
  cloudfront_distribution_domain_name = module.cloudfront.cloudfront_distribution_domain_name

  # CloudFront distribution hosted zone ID
  cloudfront_distribution_hosted_zone_id = module.cloudfront.cloudfront_distribution_hosted_zone_id

  validation_domains = [var.domain_name, "*.${var.domain_name}"]

  # CloudFront distribution ARN
  cloudfront_distribution_arn = module.cloudfront.cloudfront_distribution_arn

  # Content-Type map for S3 objects
  mime_types = {
    "html"  = "text/html"
    "css"   = "text/css"
    "js"    = "application/javascript"
    "mjs"   = "application/javascript"
    "json"  = "application/json"
    "png"   = "image/png"
    "jpg"   = "image/jpeg"
    "jpeg"  = "image/jpeg"
    "gif"   = "image/gif"
    "svg"   = "image/svg+xml"
    "ico"   = "image/x-icon"
    "webp"  = "image/webp"
    "woff"  = "font/woff"
    "woff2" = "font/woff2"
    "ttf"   = "font/ttf"
    "txt"   = "text/plain"
    "map"   = "application/json"
  }

}
