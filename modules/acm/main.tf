resource "aws_acm_certificate" "this" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  tags = merge(var.tags, {
    Name = "${var.environment}-cert"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Waits for ACM to detect the DNS record and mark the certificate as ISSUED
# So basically we have the same value for both
# dvo.resource_record_name and this var.acm_validation_records_fqdns minus the trailing dot
# It basically works as like an explicit dependency
# Terraform reads this block and does not proceed unless the certificate is validated
# and in our case acm validation is based on the DNS records that are created in the route53
# So basically terraform waits for the ACM certificate to be validated which in turn
# waits for the DNS records to be created in the route53, then it checks for the validation to be completed.

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = var.acm_validation_records_fqdns
}
