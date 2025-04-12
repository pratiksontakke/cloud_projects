# monitoring.tf

# --- CloudWatch Dashboard ---
# Logic: Define a dashboard with key metrics for visibility.
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-Dashboard"

  # Dashboard body defined in JSON format
  dashboard_body = jsonencode({
    widgets = [
      # --- ALB Metrics ---
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            # Healthy hosts count
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", aws_lb_target_group.app.name, "LoadBalancer", split("/", aws_lb.main.arn)[1], { stat = "Average" }],
            # Unhealthy hosts count
            ["AWS/ApplicationELB", "UnHealthyHostCount", "TargetGroup", aws_lb_target_group.app.name, "LoadBalancer", split("/", aws_lb.main.arn)[1], { stat = "Average" }],
            # Request count
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", split("/", aws_lb.main.arn)[1], { stat = "Sum" }],
            # 5xx Errors from ALB/Targets
            [ "...", "HTTPCode_Target_5XX_Count", { stat = "Sum" }],
            [ "...", "HTTPCode_ELB_5XX_Count", { stat = "Sum" }],
            # Target Connection Errors
            [ "...", "TargetConnectionErrorCount", { stat = "Sum" }]
          ],
          period = 300 # 5 minutes
          stat   = "Average"
          region = var.aws_region
          title  = "ALB Metrics (${aws_lb.main.name})"
        }
      },
      # --- ASG / EC2 Metrics ---
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            # Average CPU Utilization
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.app.name, { stat = "Average" }],
            # Network Out Bytes
            [ "...", "NetworkOut", { stat = "Average" }],
            # Network In Bytes
            [ "...", "NetworkIn", { stat = "Average" }]
          ],
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ASG Metrics (${aws_autoscaling_group.app.name})"
          yAxis = {
             left = {
                min = 0
                max = 100 # For CPU Percentage
             }
          }
        }
      },
      # --- RDS Metrics ---
      {
        type   = "metric"
        x      = 0
        y      = 6 # Place below ALB widget
        width  = 12
        height = 6
        properties = {
          metrics = [
            # CPU Utilization
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.main.id, { stat = "Average" }],
            # Database Connections
            [ "...", "DatabaseConnections", { stat = "Average" }],
             # Freeable Memory
            [ "...", "FreeableMemory", { stat = "Average" }],
             # Read IOPS
            [ "...", "ReadIOPS", { stat = "Average" }],
             # Write IOPS
            [ "...", "WriteIOPS", { stat = "Average" }]
          ],
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "RDS Metrics (${aws_db_instance.main.identifier})"
        }
      }
      # Add more widgets as needed (e.g., latency, specific app logs)
    ]
  })
}



# monitoring.tf (Add Parameter Store resource)

# Placeholder CloudWatch Agent Config - customize for your application's logs
variable "cloudwatch_agent_config" {
  description = "JSON configuration for the CloudWatch Agent."
  type        = string
  default = <<EOF
{
  "agent": {
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/opt/app/logs/app.log", # IMPORTANT: Change to your app's actual log file path
            "log_group_name": "/${var.project_name}/${var.environment}/app.log",
            "log_stream_name": "{instance_id}",
            "timestamp_format": "%Y-%m-%d %H:%M:%S", # Adjust format if needed
            "multi_line_start_pattern": "{timestamp_format}" # Adjust if needed
          },
          {
            "file_path": "/var/log/messages", # Example system logs
            "log_group_name": "/${var.project_name}/${var.environment}/system.log",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
EOF
}

resource "aws_ssm_parameter" "cloudwatch_agent_config" {
  name        = "/${var.project_name}/${var.environment}/cloudwatch-agent-config"
  description = "CloudWatch Agent configuration"
  type        = "String" # Use SecureString if config contains sensitive info
  value       = var.cloudwatch_agent_config

  tags = {
    Name        = "${var.project_name}-CW-Agent-Config"
    Environment = var.environment
    Terraform   = "true"
  }
}