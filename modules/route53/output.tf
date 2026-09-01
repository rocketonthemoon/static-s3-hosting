output "route53_zone_id" {
  value = data.aws_route53_zone.main.zone_id
}

output "route53_zone_name" {
  value = data.aws_route53_zone.main.name
}

output "validation_record_fqdns" {
  description = "List of FQDNs for ACM certificate validation"
  value       = [for record in aws_route53_record.acm_validation : record.fqdn]
}
