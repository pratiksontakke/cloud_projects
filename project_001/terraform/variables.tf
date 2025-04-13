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

# variables.tf (Add these variables)

variable "db_name" {
  description = "The name of the PostgreSQL database to create."
  type        = string
  default     = "project01db" # Example name, make it descriptive
}

variable "db_username" {
  description = "The master username for the PostgreSQL database."
  type        = string
  default     = "dbadmin"
  # Avoid common names like 'postgres' or 'admin' if possible for slight security improvement.
}

# Note: db_password is not defined here; it will be generated randomly.

variable "db_instance_class" {
  description = "The instance class for the RDS database."
  type        = string
  default     = "db.t3.micro"
  # Why db.t3.micro? It's often included in the AWS Free Tier for new accounts (subject to terms).
  # Check current AWS Free Tier details. For better price/performance non-free tier, consider Graviton (e.g., "db.t4g.micro").
}

variable "db_allocated_storage" {
  description = "The allocated storage size in GB for the RDS database."
  type        = number
  default     = 20
  # Free Tier typically includes up to 20GB of General Purpose (SSD) storage.
}

variable "db_port" {
  description = "db port."
  type        = number
  default     = 5432
  # Free Tier typically includes up to 20GB of General Purpose (SSD) storage.
}

# variables.tf (Add these variables)

variable "ec2_instance_type" {
  description = "EC2 instance type for the application servers."
  type        = string
  default     = "t3.micro" # Align with RDS free tier aim, consider t4g.micro for Graviton
}

variable "ami_owner" {
  description = "Owner alias for the AMI lookup (e.g., 'amazon', 'self', 'aws-marketplace')."
  type        = string
  default     = "amazon"
}

variable "ami_filter_name" {
  description = "Name filter pattern for the AMI lookup. Uses wildcards."
  type        = string
  # Pattern for Amazon Linux 2023 x86_64 HVM EBS AMIs
  # Example matched name: al2023-ami-2023.4.20240416.0-kernel-6.1-x86_64
  default     = "al2023-ami-*-kernel-*-x86_64"
}

variable "app_source_url" {
  description = "URL to the application source code archive (e.g., zip/tar.gz in S3 or a Git repo URL)."
  type        = string
  # Example: "https://github.com/your-username/your-simple-app.git"
  # For this project, you NEED to provide a URL to a simple web app boilerplate
  # that reads DB config from environment variables and listens on port 3000.
  default = "https://github.com/pratiksontakke/cloud_projects.git" # Placeholder! Use a real simple webapp
}

variable "app_port" {
  description = "Port the application listens on within the EC2 instance."
  type        = number
  default     = 8080 # Must match the ALB Target Group port
}

# variables.tf (Add this variable)

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for the ALB HTTPS listener."
  type        = string
  default     = "" # IMPORTANT: Replace with your actual ACM certificate ARN
  # Example: "arn:aws:acm:us-east-1:123456789012:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}

variable "bastion_instance_type" {
  description = "EC2 instance type for the Bastion Host."
  type        = string
  default     = "t3.micro"
}

variable "ec2_key_name" {
  description = "Name of the existing EC2 Key Pair to associate with instances."
  type        = string
  default     = "aws_linux_mumbai" # Your pre-existing key name
}