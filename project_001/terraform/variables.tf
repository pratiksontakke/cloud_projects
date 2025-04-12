# variables.tf

variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "ap-south-1" # Choose your preferred region
}

variable "vpc_cidr_block" {
  description = "The main CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
  # Why /16? Provides 65,536 IPs. A good balance for flexibility without being excessive for many scenarios.
  # Ensures enough space for various subnets (public, private, database, future growth).
}

variable "project_name" {
  description = "A name prefix for resources to help identify them."
  type        = string
  default     = "project01"
}

variable "environment" {
  description = "The deployment environment (e.g., dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "num_azs" {
  description = "Number of Availability Zones to use."
  type        = number
  default     = 3
  # Why 3 AZs? Provides better high availability than 2. If one AZ fails,
  # resources (ALB, ASG, RDS Multi-AZ standby) still operate across two healthy AZs.
}