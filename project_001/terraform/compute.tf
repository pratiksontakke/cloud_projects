# compute.tf

# --- Find latest AMI ID ---
data "aws_ami" "latest_ami" {
  most_recent = true
  owners      = [var.ami_owner]

  filter {
    name   = "name"
    values = [var.ami_filter_name]
  }

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
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-EC2-SG"
  description = "Allow traffic from ALB and outbound to DB and Internet"
  vpc_id      = aws_vpc.main.id

  # Ingress: Allow traffic from the ALB Security Group on the application port
  ingress {
    description     = "Allow traffic from ALB"
    from_port       = var.app_port # e.g., 3000
    to_port         = var.app_port
    protocol        = "tcp"
    # IMPORTANT: Reference the ALB security group ID
    security_groups = [aws_security_group.alb.id]
  }

  # (Optional) Allow SSH only from specific bastion/admin SG or IP - for debug only if not using SSM
  ingress {
    description = "Allow SSH from admin IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Replace with your IP
  }

  # Egress: Allow outbound traffic to the RDS Security Group on the PostgreSQL port
  egress {
    description     = "Allow outbound traffic to RDS DB"
    from_port       = 5432 # PostgreSQL port
    to_port         = 5432
    protocol        = "tcp"
    # IMPORTANT: Reference the RDS security group ID
    security_groups = [aws_security_group.rds.id]
  }

  # Egress: Allow all other outbound traffic (needed for yum updates, external APIs via NAT GW)
  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1" # All protocols
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"] # If using IPv6
  }

  tags = {
    Name        = "${var.project_name}-EC2-SG"
    Environment = var.environment
    Terraform   = "true"
  }
}

# --- Launch Template ---
# Logic: Defines the configuration for instances launched by the ASG.
resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-${var.environment}-"
  description   = "Launch template for Foundational Web App instances"
  image_id      = data.aws_ami.latest_ami.id
  instance_type = var.ec2_instance_type

  # Attach the IAM role via the instance profile
  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2_profile.arn
  }

  # Network interfaces configuration
  network_interfaces {
    # Associate the EC2 Security Group
    associate_public_ip_address = false # Instances are in private subnets
    security_groups             = [aws_security_group.ec2.id]
  }

  # Tagging specifications for instances and volumes launched from this template
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

  # User Data script, referencing the template file
  # Passes necessary variables to the script template
# compute.tf (Modify templatefile function in aws_launch_template.app)
  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    app_source_url     = var.app_source_url
    db_secret_arn      = aws_secretsmanager_secret.db_credentials.arn
    aws_region         = var.aws_region
    db_host            = aws_db_instance.main.address
    db_port            = aws_db_instance.main.port
    db_name            = aws_db_instance.main.db_name
    app_port           = var.app_port
    # Add these lines for CW Agent config
    cw_agent_config_param_name = aws_ssm_parameter.cloudwatch_agent_config.name # Pass Parameter Store name
    # Pass project and environment if needed inside the script (used above in CW_AGENT_CONFIG_PARAM_NAME construction)
    project_name       = var.project_name
    environment        = var.environment
  }))

  # Metadata options (optional but recommended for security)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Use IMDSv2 for enhanced security
    # http_put_response_hop_limit = 1        # Default is 1
    # instance_metadata_tags      = "enabled"  # If needed
  }

  lifecycle {
    create_before_destroy = true
  }

  
}

# --- Auto Scaling Group ---
resource "aws_autoscaling_group" "app" {
  name_prefix = "${var.project_name}-${var.environment}-ASG-"

  # Sizing parameters
  min_size         = 2 # Minimum 2 for High Availability across AZs
  max_size         = 5 # Example maximum limit
  desired_capacity = 2 # Start with 2 instances

  # Health check configuration
  health_check_type    = "ELB" # Use ALB health checks to determine instance health
  health_check_grace_period = 300 # Seconds to allow instance to start before checking health

  # Launch template specification
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest" # Always use the latest version of the launch template
  }

  # Subnets for launching instances - use private subnets for security
  vpc_zone_identifier = aws_subnet.private[*].id # Reference private subnets from network.tf

  # Associate with the ALB Target Group
  # ASG will automatically register/deregister instances with this TG
  target_group_arns = [aws_lb_target_group.app.arn] # Reference TG from alb.tf

  # Instance termination policies
  # Default usually works well, can customize (e.g., 'OldestInstance')
  # termination_policies = ["Default"]

  # Tagging for instances launched by this ASG (merged with Launch Template tags)
  tag {
    key                 = "ASG-Group"
    value               = "${var.project_name}-${var.environment}"
    propagate_at_launch = true
  }
   tag {
    key                 = "Name" # Override Name tag if desired at ASG level
    value               = "${var.project_name}-ASG-Instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# --- Scaling Policies and Alarms ---

# Scale Up Policy
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.project_name}-scale-up"
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity" # Add a specific number of instances
  scaling_adjustment     = 1                  # Add 1 instance
  cooldown               = 300                # Seconds before another scale-up activity can start
  policy_type            = "SimpleScaling"    # Could use Step or Target Tracking scaling
}

# CloudWatch Alarm to trigger Scale Up Policy
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-cpu-high-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2 # Number of consecutive periods threshold must be met
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120 # Seconds (2 minutes)
  statistic           = "Average"
  threshold           = 70 # Percent CPU utilization to trigger scale up
  alarm_description   = "Alarm when CPU exceeds 70%"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
  alarm_actions = [aws_autoscaling_policy.scale_up.arn]
}

# Scale Down Policy
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.project_name}-scale-down"
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1                 # Remove 1 instance
  cooldown               = 300
  policy_type            = "SimpleScaling"
}

# CloudWatch Alarm to trigger Scale Down Policy
resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.project_name}-cpu-low-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300 # Use a longer period for scale down (5 minutes)
  statistic           = "Average"
  threshold           = 30 # Percent CPU utilization to trigger scale down
  alarm_description   = "Alarm when CPU is below 30%"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
  alarm_actions = [aws_autoscaling_policy.scale_down.arn]
}


# compute.tf (Remove Simple Scaling policies/alarms, add Target Tracking)

# Remove these resources:
# resource "aws_autoscaling_policy" "scale_up" { ... }
# resource "aws_cloudwatch_metric_alarm" "cpu_high" { ... }
# resource "aws_autoscaling_policy" "scale_down" { ... }
# resource "aws_cloudwatch_metric_alarm" "cpu_low" { ... }

# --- Target Tracking Scaling Policy ---
# Logic: Keeps average CPU utilization across the ASG at the target value (e.g., 60%).
resource "aws_autoscaling_policy" "avg_cpu_target_tracking" {
  name                   = "${var.project_name}-avg-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling" # Specify Target Tracking type

  target_tracking_configuration {
    predefined_metric_specification {
      # Use average CPU utilization across the group
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    # Target value for the metric (e.g., 60% CPU)
    target_value = 60.0

    # Optional: Disable scale-in to prevent rapid instance termination (can save costs but might overprovision slightly)
    # disable_scale_in = false
  }
}

# --- Auto Scaling Group (ensure health_check_type uses ELB) ---
# Ensure this section in your ASG definition is present:
resource "aws_autoscaling_group" "app" {
  # ... other parameters ...
  name_prefix          = "${var.project_name}-${var.environment}-ASG-"
  min_size             = 2
  max_size             = 5
  desired_capacity     = 2
  health_check_type    = "ELB" # Ensures ASG uses ALB health checks
  health_check_grace_period = 300
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }
  vpc_zone_identifier = aws_subnet.private[*].id
  target_group_arns   = [aws_lb_target_group.app.arn]
  tag {
    key                 = "Name"
    value               = "${var.project_name}-ASG-Instance"
    propagate_at_launch = true
  }
  # ... other tags, lifecycle rules ...

   # IMPORTANT: Remove or comment out the 'depends_on' for the old alarms if you had any
}






