variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "enable_vpc" {
  description = "Enable VPC configuration for Lambda (default: true)"
  type        = bool
  default     = true
}

variable "project_name" {
  description = "Project name for resource naming and tagging"
  type        = string
  default     = "hello-vpc"
}

variable "environment" {
  description = "Environment name for tagging"
  type        = string
  default     = "dev"
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period in days"
  type        = number
  default     = 7
}

variable "allowed_origins" {
  description = "Allowed origins for API Gateway CORS (e.g., localhost and CloudFront domains)"
  type        = list(string)
  default     = ["http://localhost:3000"]
}

locals {
  common_tags = {
    project = var.project_name
    env     = var.environment
  }
}
