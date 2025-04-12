# iam.tf

# --- IAM Role for EC2 Instances ---
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-${var.environment}-EC2-Role"

  # Trust policy allowing EC2 service to assume this role
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-EC2-Role"
    Environment = var.environment
    Terraform   = "true"
  }
}

# --- IAM Policy for accessing Secrets Manager and CloudWatch Logs ---
resource "aws_iam_policy" "ec2_policy" {
  name        = "${var.project_name}-${var.environment}-EC2-Policy"
  description = "Policy for EC2 instances to access Secrets Manager DB secret and CloudWatch Logs"

  # Policy document granting specific permissions
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        # Allow reading the specific DB credentials secret
        Action = [
          "secretsmanager:GetSecretValue"
        ],
        Effect   = "Allow",
        # IMPORTANT: Reference the secret ARN output from database.tf
        Resource = aws_secretsmanager_secret.db_credentials.arn
      },
      {
        # Allow CloudWatch Logs actions (if using CloudWatch Agent)
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*" # Allow access to any log group/stream (can be restricted)
      }
      # Add other permissions here if needed (e.g., S3 access)
    ]
  })
}

# --- Attach Custom Policy to Role ---
resource "aws_iam_role_policy_attachment" "ec2_custom_policy_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_policy.arn
}

# --- Attach Managed Policy for Systems Manager Core ---
# Logic: Provides permissions needed for SSM features like Session Manager (secure shell access)
resource "aws_iam_role_policy_attachment" "ec2_ssm_policy_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" # AWS Managed Policy ARN
}

# --- Create Instance Profile ---
# Logic: An instance profile is a container for an IAM role that you can use to pass role information to an EC2 instance when the instance starts.
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-${var.environment}-EC2-Profile"
  role = aws_iam_role.ec2_role.name

  tags = {
    Name        = "${var.project_name}-EC2-Profile"
    Environment = var.environment
    Terraform   = "true"
  }
}