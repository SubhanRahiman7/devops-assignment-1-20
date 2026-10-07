terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # ---- Optional: run the same code against a local AWS emulator (Moto) --------------
  # Default (use_local_emulator = false) talks to real AWS with your normal credentials.
  access_key                  = var.use_local_emulator ? "test" : null
  secret_key                  = var.use_local_emulator ? "test" : null
  skip_credentials_validation = var.use_local_emulator
  skip_requesting_account_id  = var.use_local_emulator
  skip_metadata_api_check     = var.use_local_emulator
  s3_use_path_style           = var.use_local_emulator

  endpoints {
    s3  = var.use_local_emulator ? var.emulator_endpoint : null
    sts = var.use_local_emulator ? var.emulator_endpoint : null
  }
}
