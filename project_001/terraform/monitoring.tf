# monitoring.tf

# --- Locals Block for Dynamic Configurations ---
locals {
  # Construct the CloudWatch agent configuration JSON string dynamically here
  # Using a HEREDOC string allows for multi-line JSON with variable interpolation.
  cw_agent_config_json = <<EOF
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
            "log_group_name": "/${var.project_name}/${var.environment}/app.log", # Interpolation works here!
            "log_stream_name": "{instance_id}",
            "timestamp_format": "%Y-%m-%d %H:%M:%S", # Adjust format if needed
            "multi_line_start_pattern": "{timestamp_format}" # Adjust if needed for multi-line logs
          },
          {
            "file_path": "/var/log/messages", # Example system logs
            "log_group_name": "/${var.project_name}/${var.environment}/system.log", # Interpolation works here!
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    },
    "log_stream_name": "${var.project_name}-${var.environment}-DefaultLogStream", # Optional: Default stream name if others fail
    "force_flush_interval": 15
  },
  "metrics": {
     "metrics_collected": {
       "collectd": {
         "metrics_aggregation_interval": 60
       },
       "cpu": {
         "measurement": [
           "cpu_usage_idle",
           "cpu_usage_nice",
           "cpu_usage_system",
           "cpu_usage_user",
           "cpu_usage_wait"
         ],
         "metrics_collection_interval": 60,
         "totalcpu": true
       },
       "disk": {
         "measurement": [
           "used_percent",
           "inodes_free"
         ],
         "metrics_collection_interval": 60,
         "resources": [
           "/"
         ]
       },
       "mem": {
         "measurement": [
           "mem_used_percent"
         ],
         "metrics_collection_interval": 60
       },
       "swap": {
         "measurement": [
           "swap_used_percent"
         ],
         "metrics_collection_interval": 60
       }
     },
     # Optional: Add aggregation dimensions if needed
     # "append_dimensions": {
     #   "AutoScalingGroupName": "$${aws:AutoScalingGroupName}",
     #   "ImageId": "$${aws:ImageId}",
     #   "InstanceId": "$${aws:InstanceId}",
     #   "InstanceType": "$${aws:InstanceType}"
     # }
     "aggregation_interval": 60 # How often metrics are aggregated and sent (seconds)
  }
}
EOF
}


# --- CloudWatch SSM Parameter for Agent Configuration ---
# Logic: Store the dynamically generated agent config in Parameter Store
resource "aws_ssm_parameter" "cloudwatch_agent_config" {
  # Construct the name using variables
  name        = "/${var.project_name}/${var.environment}/cloudwatch-agent-config"
  description = "CloudWatch Agent configuration for ${var.project_name} ${var.environment}"
  type        = "String" # Use SecureString only if the config itself contains secrets
  # Use the JSON string defined in the locals block
  value       = local.cw_agent_config_json

  tags = {
    Name        = "${var.project_name}-CW-Agent-Config"
    Environment = var.environment
    Terraform   = "true"
  }
}


# --- CloudWatch Dashboard ---
# Logic: Define a dashboard with key metrics for visibility.
# RETAIN THIS (Ensure resource references are valid)
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
            # Using simplified references - ensure aws_lb_target_group.app and aws_lb.main exist
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", element(split("/", aws_lb_target_group.app.arn), 1), "LoadBalancer", element(split("/", aws_lb.main.arn), 1)],
            ["AWS/ApplicationELB", "UnHealthyHostCount", "TargetGroup", element(split("/", aws_lb_target_group.app.arn), 1), "LoadBalancer", element(split("/", aws_lb.main.arn), 1)],
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", element(split("/", aws_lb.main.arn), 1), { stat = "Sum" }],
            # Use "..." shorthand for namespace/dimensions if they are the same as the previous metric line
            [ "...", "HTTPCode_Target_5XX_Count", { stat = "Sum" }],
            [ "...", "HTTPCode_ELB_5XX_Count", { stat = "Sum" }],
            [ "...", "TargetConnectionErrorCount", { stat = "Sum" }]
          ],
          period = 300 # 5 minutes
          stat   = "Average" # Default statistic for the widget if not specified per metric
          region = var.aws_region
          title  = "ALB Metrics (${element(split("/", aws_lb.main.arn), 1)})" # Use element/split to get ALB name
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
            # Ensure aws_autoscaling_group.app exists
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.app.name, { stat = "Average" }],
            # Using "..." shorthand
            [ "...", "NetworkOut", { stat = "Average" }],
            [ "...", "NetworkIn", { stat = "Average" }]
            # Optional: Add Disk metrics if needed (requires CW Agent sending custom metrics)
            # ["CWAgent", "disk_used_percent", "AutoScalingGroupName", aws_autoscaling_group.app.name, "InstanceId", "*", "path", "/", "fstype", "*", "device", "*"]
          ],
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ASG Metrics (${aws_autoscaling_group.app.name})"
          yAxis = {
             left = { min = 0, max = 100 } # For CPU Percentage
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
            # Ensure aws_db_instance.main exists
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.main.id, { stat = "Average" }],
            [ "...", "DatabaseConnections", { stat = "Average" }],
            [ "...", "FreeableMemory", { stat = "Average" }],
            [ "...", "ReadIOPS", { stat = "Average" }],
            [ "...", "WriteIOPS", { stat = "Average" }]
          ],
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "RDS Metrics (${aws_db_instance.main.identifier})"
        }
      },
      # Add more widgets: e.g., CW Agent Memory %
       {
        type   = "metric",
        x      = 12,
        y      = 6, # Below ASG widget
        width  = 12,
        height = 6,
        properties = {
          metrics = [
              [ "CWAgent", "mem_used_percent", "AutoScalingGroupName", aws_autoscaling_group.app.name ]
              # Add other custom metrics from agent if configured
          ],
          period = 300,
          stat   = "Average",
          region = var.aws_region
          title  = "EC2 Instance Memory (via CW Agent)",
          yAxis = {
            left = { min = 0, max = 100 }
          }
        }
      }
    ]
  })
}