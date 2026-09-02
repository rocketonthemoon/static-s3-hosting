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

  # allow_overwrite = true otherwise route53 crashes with a duplicate record error.
  # this happens because we are creating two acm validation records,
  #  one for the root domain and one for the wildcard domain.
  # (both have same acm validation token)
  # Route53 updates and overwrites records with same name.
  allow_overwrite = true
  zone_id         = data.aws_route53_zone.main.zone_id
  ttl             = 60


  # var.domain_validation_options =  [
  #   {
  #     domain_name = "namecheap-test.me",
  #     resource_record_name = "_a1bqwdq2c3.namecheap-test.me",
  #     resource_record_type = "CNAME",
  #     resource_record_value = "_x1yqdw2z3.acm-validations.aws." },
  #   {
  #     domain_name = "*.namecheap-test.me",
  #     resource_record_name = "_a1bqwd2c3.namecheap-test.me",
  #     resource_record_type = "CNAME",
  #     resource_record_value = "_x1yqdw2z3.acm-validations.aws." }
  # ]
  # var.validation_domains = ["namecheap-test.me", "*.namecheap-test.me"]
  # 
  # name = [ [for dvo in var.domain_validation_options : dvo.resource_record_name if dvo.domain_name == each.value][0] ]
  # records = [ [for dvo in var.domain_validation_options : dvo.resource_record_value if dvo.domain_name == each.value] ]
  # type = [ [for dvo in var.domain_validation_options : dvo.resource_record_type if dvo.domain_name == each.value][0] ]
  # 
  # first iteration validation_domains = namecheap-test.me
  # 
  # final name = "_a1bqwdq2c3.namecheap-test.me"
  # final records = ["_x1y2edqwz3.acm-validations.aws."]
  # final type = "CNAME"
  #
  # second iteration validation_domains = *.namecheap-test.me
  # final name = "_a1bqwd2c3.namecheap-test.me"
  # final records = ["_x1yqdw2z3.acm-validations.aws."]
  # final type = "CNAME"
  #
  # Note: here we are creating two acm validation records, one for the root domain and one for the wildcard domain.
  #       values are similar because its for the same domain and its wildcard counterpart, so route53 actually overrides it.
  #       also name and type should only have one value, so we take [0] index. we do not take [0] for records 
  #       because it is a list (even though it only has one value)

  name = [
    for dvo in var.domain_validation_options : dvo.resource_record_name
    if dvo.domain_name == each.value
  ][0]

  records = [
    for dvo in var.domain_validation_options : dvo.resource_record_value
    if dvo.domain_name == each.value
  ]

  type = [
    for dvo in var.domain_validation_options : dvo.resource_record_type
    if dvo.domain_name == each.value
  ][0]
}
