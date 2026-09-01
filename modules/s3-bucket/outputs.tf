output "bucket_name" {
  description = "Name of the bucket"
  value       = aws_s3_bucket.this.bucket
}

output "bucket_arn" {
  description = "ARN of the bucket"
  value       = aws_s3_bucket.this.arn
}

output "website_endpoint" {
  description = "Website endpoint"
  value       = aws_s3_bucket_website_configuration.this.website_endpoint
}

output "regional_domain_name" {
  description = "Regional domain name"
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}
