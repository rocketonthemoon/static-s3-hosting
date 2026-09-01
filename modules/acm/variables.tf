variable "domain_name" {
  description = "Domain name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Tags to apply to the resources"
  type        = map(string)
  default     = {}
}

variable "route53_zone_id" {
  description = "Route53 zone ID"
  type        = string
}

variable "acm_validation_records_fqdns" {
  description = "Route53 fqdns"
  type        = list(string)
}
