output "route53_zone_id" {
  value = data.aws_route53_zone.main.zone_id
}

output "route53_zone_name" {
  value = data.aws_route53_zone.main.name
}

# The output will contain: validation_record_fqdns = ["_a1bqwdq2c3.your-domain.com", "_a1bqwdq2c3.your-domain.com"]
# explanation : We need to create two acm validation records, one for the root domain and one for the wildcard domain.
# (both have same acm validation token)
# Route53 updates and overwrites records with same name.
output "validation_record_fqdns" {
  description = "List of FQDNs for ACM certificate validation"
  value       = [for record in aws_route53_record.acm_validation : record.fqdn]
}
