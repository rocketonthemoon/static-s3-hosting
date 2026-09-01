variable "domain_name" {
  description = "Domain name"
  type        = string
}

variable "domain_validation_options" {
  description = "ACM domain validation options"
  type        = list(any)
}

variable "cloudfront_distribution_domain_name" {
  description = "CloudFront distribution domain name"
  type        = string
}

variable "cloudfront_distribution_hosted_zone_id" {
  description = "CloudFront distribution hosted zone ID"
  type        = string
}

variable "validation_domains" {
  description = "List of domains to validate"
  type        = list(string)
}
