variable "aws_region" {
  type        = string
  description = "AWS region for all resources."
  default     = "ap-south-1"
}

variable "project_name" {
  type        = string
  description = "Name prefix used for resource names and tags."
  default     = "session19"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block of the VPC."
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  type        = string
  description = "CIDR block of the public subnet."
  default     = "10.20.1.0/24"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type."
  default     = "t3.micro"
}

variable "ami_id" {
  type        = string
  description = "AMI to launch. Empty = look up the latest Amazon Linux 2023 AMI (real AWS)."
  default     = ""
}

variable "ssh_cidr" {
  type        = string
  description = "CIDR allowed to SSH (port 22). Restrict this to your own IP, e.g. 203.0.113.10/32."
  default     = "10.0.0.0/8"
}

variable "bucket_name" {
  type        = string
  description = "Globally unique S3 bucket name for the application artifacts."
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
