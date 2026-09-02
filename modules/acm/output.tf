output "acm_certificate_arn" {
  description = "The ARN of the validated ACM certificate"
  value       = aws_acm_certificate_validation.this.certificate_arn
}

# example domain_validation_options
# [ {domain_name = "your-domain.com",
#   resource_record_name = "_a1bqwdq2c3.your-domain.com",
#   resource_record_type = "CNAME",
#   resource_record_value = "_x1y2edqwz3.acm-validations.aws."}]
output "domain_validation_options" {
  value = aws_acm_certificate.this.domain_validation_options
}
