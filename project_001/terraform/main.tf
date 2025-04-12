# main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Use a recent version
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data source to get the list of available AZs in the current region
# Thinking: Avoids hardcoding AZ names like 'us-east-1a', making the code region-agnostic.
data "aws_availability_zones" "available" {
  state = "available"
}