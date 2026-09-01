data "aws_route53_zone" "main" {
  name = var.domain_name
}

resource "aws_route53_record" "root" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.cloudfront_distribution_domain_name
    zone_id                = var.cloudfront_distribution_hosted_zone_id
    evaluate_target_health = false
  }
}

# Creates the Route 53 validation CNAME record(s) dynamically using for_each
resource "aws_route53_record" "acm_validation" {
  for_each = toset(var.validation_domains)

  allow_overwrite = true
  zone_id         = data.aws_route53_zone.main.zone_id
  ttl             = 60

  name = [
    for dvo in var.domain_validation_options : dvo.resource_record_name
    if dvo.domain_name == each.value
  ][0]

  records = [
    [
      for dvo in var.domain_validation_options : dvo.resource_record_value
      if dvo.domain_name == each.value
    ][0]
  ]

  type = [
    for dvo in var.domain_validation_options : dvo.resource_record_type
    if dvo.domain_name == each.value
  ][0]
}
