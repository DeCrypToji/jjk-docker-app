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

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "jjk.decryptoji.com"
}

variable "ecr_image_uri" {
  description = "Full ECR image URI including tag"
  type        = string
  default     = "119750096239.dkr.ecr.eu-central-1.amazonaws.com/jjk-docker-app:latest"
}