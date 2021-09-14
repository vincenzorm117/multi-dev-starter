
# AWS credentials
variable "aws_access_key" {
  type        = string
  description = "AWS programmatic access key"
}

variable "aws_secret_key" {
  type        = string
  description = "AWS programmatic secret key"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
}

# General
variable "team" {
  type        = string
  description = "Name of team. This is prefixed into all resource names to avoid collisions with other projects using similar resources."
}

# Sites
variable "static_sites" {
  type = list(object({
    hostname = string
    project  = string
  }))

  description = "List of static sites. The following are provisioned: S3 bucket, Cloudfront distribution, Lambda Edge function, ACM entry."
}
