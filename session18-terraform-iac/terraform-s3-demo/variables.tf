variable "aws_region" {
  type        = string
  description = "AWS region where the S3 bucket will be created."
  default     = "ap-south-1"
}

variable "bucket_name" {
  type        = string
  description = "Globally unique name of the S3 bucket."
}

variable "environment" {
  type        = string
  description = "Environment tag."
  default     = "dev"
}

variable "use_local_emulator" {
  type        = bool
  description = "true = send API calls to a local AWS emulator (Moto) instead of real AWS."
  default     = false
}

variable "emulator_endpoint" {
  type        = string
  description = "URL of the local AWS emulator (only used when use_local_emulator = true)."
  default     = "http://localhost:5555"
}
