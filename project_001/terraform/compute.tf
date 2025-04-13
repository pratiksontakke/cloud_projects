# compute.tf

# --- Find latest AMI ID ---
# RETAIN
data "aws_ami" "latest_ami" {
  most_recent = true
  owners      = [var.ami_owner] # Ensure var.ami_owner is defined

  filter {
    name   = "name"
    values = [var.ami_filter_name] # Ensure var.ami_filter_name is defined
  }
  # Keep other filters as they were
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# --- Security Group for EC2 Instances ---
# RETAIN (Modify SSH ingress rule!)
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-EC2-SG"
  description = "Allow traffic from ALB and outbound to DB and Internet"
  vpc_id      = aws_vpc.main.id # Assumes aws_vpc.main defined in network.tf

  # Ingress: Allow traffic from the ALB Security Group on the application port
  ingress {
    description     = "Allow traffic from ALB"
    from_port       = var.app_port # Ensure var.app_port is defined (e.g., 3000)
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id] # Assumes aws_security_group.alb defined in alb.tf
  }

  # (Optional/Modify) Allow SSH - Recommended: Use SSM Session Manager instead.
  # If keeping SSH, restrict to YOUR IP address.
  ingress {
    description     = "Allow SSH from Bastion SG"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    # Source is the Bastion SG defined in bastion.tf
    security_groups = [aws_security_group.bastion.id]
  }

  # Egress: Allow outbound traffic to the RDS Security Group on the PostgreSQL port
  egress {
    description     = "Allow outbound traffic to RDS DB"
    from_port       = var.db_port # Ensure var.db_port is defined (e.g., 5432 or 3306)
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.rds.id] # Assumes aws_security_group.rds defined in database.tf
  }

  # Egress: Allow all other outbound traffic (via NAT GW)
  egress {
    description      = "Allow all other outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "${var.project_name}-EC2-SG"
    Environment = var.environment
    Terraform   = "true"
  }
}

# --- Launch Template ---
# RETAIN (Ensure referenced variables/resources exist)
resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-${var.environment}-"
  description   = "Launch template for ${var.project_name} instances"
  image_id      = data.aws_ami.latest_ami.id
  instance_type = var.ec2_instance_type # Ensure var.ec2_instance_type is defined

  # Key Pair: Associate the existing key pair for SSH login
  key_name = var.ec2_key_name

  # Assumes aws_iam_instance_profile.ec2_profile defined in iam.tf
  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2_profile.arn
  }

  network_interfaces {
    associate_public_ip_address = false # Correct for private subnets
    security_groups             = [aws_security_group.ec2.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-Instance"
      Environment = var.environment
      Terraform   = "true"
    }
  }
  tag_specifications {
    resource_type = "volume"
    tags = {
      Name        = "${var.project_name}-Volume"
      Environment = var.environment
      Terraform   = "true"
    }
  }

  # User Data script using templatefile
  # Ensure templatefile variables reference existing resources/variables
  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    # Variables needed by user_data.sh.tpl
    app_source_url             = var.app_source_url
    db_secret_arn              = aws_secretsmanager_secret.db_credentials.arn # Ensure this secret resource exists
    aws_region                 = var.aws_region
    db_host                    = aws_db_instance.main.address
    db_port                    = aws_db_instance.main.port
    db_name                    = aws_db_instance.main.db_name
    app_port                   = var.app_port
    cw_agent_config_param_name = aws_ssm_parameter.cloudwatch_agent_config.name # Ensure this parameter resource exists
    project_name               = var.project_name
    environment                = var.environment
  }))

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2 recommended
  }

  lifecycle {
    create_before_destroy = true
  }
}

# --- Auto Scaling Group ---
# RETAIN (Consolidated Version)
resource "aws_autoscaling_group" "app" {
  name_prefix = "${var.project_name}-${var.environment}-ASG-"

  # Sizing parameters
  min_size         = 2 # Ensure var.asg_min_size is defined or use hardcoded
  max_size         = 5 # Ensure var.asg_max_size is defined or use hardcoded
  desired_capacity = 2 # Ensure var.asg_desired_capacity is defined or use hardcoded

  # Health check configuration
  health_check_type         = "ELB" # Correct for ALB integration
  health_check_grace_period = 300   # Standard grace period

  # Launch template specification
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  # Subnets - Assumes aws_subnet.private defined in network.tf
  vpc_zone_identifier = aws_subnet.private[*].id

  # Associate with ALB Target Group - Assumes aws_lb_target_group.app defined in alb.tf
  target_group_arns = [aws_lb_target_group.app.arn]

  # Instance termination policies (Optional - Default is usually fine)
  # termination_policies = ["Default"]

  # Tagging for instances launched by this ASG
  tag {
    key                 = "ASG-Group"
    value               = "${var.project_name}-${var.environment}"
    propagate_at_launch = true
  }
  tag {
    key                 = "Name" # Override Name tag if desired
    value               = "${var.project_name}-ASG-Instance"
    propagate_at_launch = true
  }
  # Add other tags as needed

  lifecycle {
    create_before_destroy = true
  }

  # Remove any 'depends_on' that referenced the old CloudWatch alarms if present
}

# --- Target Tracking Scaling Policy ---
# RETAIN (Ensure target value is appropriate)
resource "aws_autoscaling_policy" "avg_cpu_target_tracking" {
  name                   = "${var.project_name}-avg-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    # Adjust target_value based on performance testing and goals
    target_value = 60.0 # Target 60% average CPU utilization
    # disable_scale_in = false # Default allows scale-in
  }
}


# REMOVE THESE RESOURCES (Simple Scaling + Alarms)
# resource "aws_autoscaling_policy" "scale_up" { ... }
# resource "aws_cloudwatch_metric_alarm" "cpu_high" { ... }
# resource "aws_autoscaling_policy" "scale_down" { ... }
# resource "aws_cloudwatch_metric_alarm" "cpu_low" { ... }