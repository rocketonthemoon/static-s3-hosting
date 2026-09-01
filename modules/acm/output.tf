output "acm_certificate_arn" {
  description = "The ARN of the validated ACM certificate"
  value       = aws_acm_certificate_validation.this.certificate_arn
}

output "domain_validation_options" {
  value = aws_acm_certificate.this.domain_validation_options
}
