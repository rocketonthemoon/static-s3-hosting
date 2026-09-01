resource "aws_cloudfront_distribution" "this" {
  #checkov:skip=CKV_AWS_68:Dev environment learning setup - WAF not required for dev
  #checkov:skip=CKV2_AWS_47:Dev environment learning setup - WAF Log4j rule not required for dev
  #checkov:skip=CKV_AWS_86:Dev environment learning setup - access logging not required
  #checkov:skip=CKV_AWS_310:Dev environment learning setup - origin failover not required
  #checkov:skip=CKV_AWS_374:Dev environment learning setup - geo restriction not required
  #checkov:skip=CKV2_AWS_32:Dev environment learning setup - response headers policy not required
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = var.default_root_object
  aliases             = [var.domain_name]
  tags                = merge(var.tags, { Name = "${var.project}-${var.environment}-cloudfront-distribution" })

  origin {
    domain_name              = var.regional_domain_name
    origin_id                = "s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
    origin_path              = var.origin_path
  }

  default_cache_behavior {
    target_origin_id       = "s3-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  custom_error_response {
    error_code            = 403
    response_code         = 403
    response_page_path    = var.error_page_path
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = var.error_page_path
    error_caching_min_ttl = 10
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}


resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "s3-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
