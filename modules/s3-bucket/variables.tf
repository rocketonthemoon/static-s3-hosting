variable "bucket_name" {
  description = "Name of the bucket"
  type        = string
}

variable "tags" {
  description = "Tags to apply to the resources"
  type        = map(string)
  default     = {}
}

variable "mime_types" {
  description = "Map of file extensions to content types"
  type        = map(string)
}

variable "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution"
  type        = string
}

variable "origin_path" {
  description = "Path to the origin"
  type        = string
}
