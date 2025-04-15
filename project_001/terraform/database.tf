# database.tf

# --- Generate Random Password ---
# Logic: Create a cryptographically secure password for the DB master user.
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "_%@" # Limit special characters if needed by RDS/Postgres, but generally safe
  # Keep state: Ensure password doesn't change on every 'apply' unless parameters change.
}

# --- Store Password in Secrets Manager ---
# Logic: Securely store the generated password. Applications should retrieve it from here.
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${var.project_name}-${var.environment}-db-credentials"
  description = "Credentials for the ${var.project_name} RDS database"

  tags = {
    Name        = "${var.project_name}-DB-Secret"
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  # Store username and password as a JSON string
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    engine   = "postgres" # Optional: Good practice to include engine/host later
    # dbname will be var.db_name
    # host endpoint will come from aws_db_instance.main.endpoint
  })
}

# --- Security Group for RDS Database ---
# Logic: Allow inbound traffic only from the application's EC2 instances (defined later) on the PostgreSQL port.
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-RDS-SG"
  description = "Allow inbound traffic from EC2 instances to PostgreSQL"
  vpc_id      = aws_vpc.main.id # Must be in the same VPC

  # Ingress Rule (Placeholder - will be updated or referenced by EC2 SG):
  # We don't know the EC2 SG ID yet. We define the DB SG now and allow EC2 SG outbound access TO this SG ID later.
  # Alternatively, you could add an ingress rule here referencing a variable or data source for the EC2 SG ID once created.
  # For now, we define NO ingress rules here initially. We'll control access via the EC2 SG's Egress rules pointing to this SG ID.

  # Egress Rule: Typically not needed for RDS unless it needs to access external resources (rare).
  # Default allows all outbound, which is usually fine.

  tags = {
    Name        = "${var.project_name}-RDS-SG"
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-RDS-SG"
  description = "Allow inbound traffic from EC2 instances to PostgreSQL"
  vpc_id      = aws_vpc.main.id # Must be in the same VPC

  ingress {
    description = "Allow PostgreSQL access from EC2 SG"
    # Use the variable defined for the database port (e.g., 5432)
    from_port   = var.db_port
    to_port     = var.db_port
    protocol    = "tcp"
    # Reference the Security Group ID of your EC2 application instances
    # Assumes you have resource "aws_security_group" "ec2" defined in compute.tf
    security_groups = [aws_security_group.ec2.id]
  }


  # Egress Rule: Typically not needed for RDS. Default allows all outbound.
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-RDS-SG"
    Environment = var.environment
    Terraform   = "true"
  }
}

# --- DB Subnet Group ---
# Logic: Tells RDS which subnets to potentially place DB instances/replicas in. Must include >1 AZ for Multi-AZ. Use PRIVATE subnets.
resource "aws_db_subnet_group" "default" {
  name       = "${var.project_name}-${var.environment}-rds-subnet-group"
  subnet_ids = aws_subnet.private[*].id # Use the private subnet IDs from network.tf

  tags = {
    Name        = "${var.project_name}-RDSSubnetGroup"
    Environment = var.environment
    Terraform   = "true"
  }
}

# --- RDS PostgreSQL Instance ---
resource "aws_db_instance" "main" {
  identifier           = "${var.project_name}-${var.environment}-db" # Unique identifier for the instance
  engine               = "postgres"
  engine_version       = "15.12" # Choose a recent, supported version
  instance_class       = var.db_instance_class
  allocated_storage    = var.db_allocated_storage
  storage_type         = "gp3" # General Purpose SSD v3 - good balance, often free tier eligible storage type
  # storage_encrypted = true # Recommended for production, requires KMS key setup (more complex)

  db_name              = var.db_name      # Initial database name created by RDS
  username             = var.db_username  # Master username
  password             = random_password.db_password.result # Pass the generated password directly

  db_subnet_group_name = aws_db_subnet_group.default.name # Use the subnet group created above
  vpc_security_group_ids = [aws_security_group.rds.id]    # Use the RDS SG created above

  # Availability & Durability
  # Multi-AZ Deployment: Set 'true' for production HA. Set 'false' for cost savings / free tier focus.
  # Explanation: multi_az=true provisions a synchronous standby replica in a DIFFERENT AZ for automatic failover.
  # This significantly increases availability but usually isn't free-tier eligible.
  multi_az             = false
  publicly_accessible  = false # Keep the database private

  # Backups
  backup_retention_period = 7     # Days (Free tier might limit this, but 7 is a common default)
  # backup_window           = "03:00-04:00" # Optional: Preferred backup window (UTC)

  # Maintenance
  # maintenance_window      = "sun:04:30-sun:05:30" # Optional: Preferred maintenance window (UTC)
  auto_minor_version_upgrade = true

  # Deletion Settings (for learning/dev)
  skip_final_snapshot = true  # Set to 'false' for production (takes a snapshot before deletion)
  deletion_protection = false # Set to 'true' for production (prevents accidental deletion via console/API)

  tags = {
    Name        = "${var.project_name}-RDS-Instance"
    Environment = var.environment
    Terraform   = "true"
  }
}