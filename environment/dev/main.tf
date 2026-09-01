terraform {

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.62.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Secondary provider alias required for CloudFront ACM certificates
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

module "s3_bucket" {
  source                      = "../../modules/s3-bucket"
  bucket_name                 = local.bucket_name
  tags                        = local.common_tags
  mime_types                  = local.mime_types
  cloudfront_distribution_arn = local.cloudfront_distribution_arn
}

module "route53" {
  source                                 = "../../modules/route53"
  domain_name                            = var.domain_name
  domain_validation_options              = local.acm_validation_options
  cloudfront_distribution_domain_name    = local.cloudfront_distribution_domain_name
  cloudfront_distribution_hosted_zone_id = local.cloudfront_distribution_hosted_zone_id
  validation_domains                     = local.validation_domains
}

module "acm" {
  source                       = "../../modules/acm"
  providers                    = { aws = aws.us_east_1 }
  domain_name                  = var.domain_name
  environment                  = var.environment
  tags                         = local.common_tags
  acm_validation_records_fqdns = local.acm_validation_records_fqdns
}

module "cloudfront" {
  source               = "../../modules/cloudfront"
  domain_name          = var.domain_name
  project              = var.project
  environment          = var.environment
  tags                 = local.common_tags
  acm_certificate_arn  = local.acm_certificate_arn
  regional_domain_name = local.s3_regional_domain_name
  origin_path          = var.origin_path
  default_root_object  = var.default_root_object
  error_page_path      = var.error_page_path
}
