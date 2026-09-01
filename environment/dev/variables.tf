variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project" {
  description = "Name of the project"
  type        = string
}

variable "domain_name" {
  description = "Domain name"
  type        = string
}

variable "origin_path" {
  description = "Origin path"
  type        = string
}

variable "default_root_object" {
  description = "Default root object"
  type        = string
}

variable "error_page_path" {
  description = "Error page path"
  type        = string
}
