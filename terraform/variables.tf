variable "region" {
  description = "AWS region"
  default     = "eu-central-1"
}

variable "app_name" {
  description = "Application name used for naming resources"
  default     = "JJK"
}

variable "ecr_image_uri" {
  description = "Full ECR image URI including tag"
  type        = string
}