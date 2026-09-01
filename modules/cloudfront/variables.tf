variable "acm_certificate_arn" {
  type = string
}

variable "project" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  type = map(string)
}

variable "domain_name" {
  type = string
}

variable "regional_domain_name" {
  type = string
}

variable "origin_path" {
  type = string
}

variable "default_root_object" {
  description = "Default root object"
  type        = string
}

variable "error_page_path" {
  description = "Error page path"
  type        = string
}
