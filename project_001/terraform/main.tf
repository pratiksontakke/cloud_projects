# main.tf (Add the 'random' provider to the 'required_providers' block)

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # Add this block for the random provider
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# Provider configurations remain the same
provider "aws" {
  region = var.aws_region
}

# Data source remains the same
data "aws_availability_zones" "available" {
  state = "available"
}