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
resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = var.acm_validation_records_fqdns
}
