# outputs.tf

output "vpc_id" {
  description = "The ID of the created VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "A list of IDs of the public subnets."
  # The [*] splat expression gets the 'id' attribute from all instances created by the 'aws_subnet.public' resource block.
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "A list of IDs of the private subnets."
  value       = aws_subnet.private[*].id
}

output "availability_zones_used" {
  description = "List of Availability Zones used for the subnets."
  # Slice the list of available AZs to match the number we actually used (var.num_azs)
  value       = slice(data.aws_availability_zones.available.names, 0, var.num_azs)
}

output "nat_gateway_eip" {
  description = "The public IP address of the NAT Gateway."
  value       = aws_eip.nat.public_ip
}



output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer."
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "The Zone ID of the Application Load Balancer (for Route53 Alias records)."
  value       = aws_lb.main.zone_id
}

output "alb_target_group_arn" {
  description = "The ARN of the Application Load Balancer's Target Group."
  value       = aws_lb_target_group.app.arn
}

output "alb_security_group_id" {
  description = "The ID of the Security Group attached to the ALB."
  value       = aws_security_group.alb.id
}




# outputs.tf (Add these to the existing file)

output "db_instance_endpoint" {
  description = "The connection endpoint for the RDS database instance."
  value       = aws_db_instance.main.endpoint
  sensitive   = true # Endpoint might be considered sensitive
}

output "db_instance_port" {
  description = "The port for the RDS database instance."
  value       = aws_db_instance.main.port
}

output "db_instance_name" {
  description = "The database name (DBName) for the RDS database instance."
  value       = aws_db_instance.main.db_name
}

output "db_security_group_id" {
  description = "The ID of the Security Group attached to the RDS instance."
  value       = aws_security_group.rds.id
}

output "db_credentials_secret_arn" {
  description = "The ARN of the Secrets Manager secret containing the DB credentials."
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_credentials_secret_password" {
  description = "password of db"
  value       = aws_db_instance.main.password
  sensitive = true
}

output "db_credentials_secret_username" {
  description = "username of db."
  value       = aws_db_instance.main.username
}
# outputs.tf (Add this output)

output "autoscaling_group_name" {
  description = "The name of the Auto Scaling Group."
  value       = aws_autoscaling_group.app.name
}

output "ec2_security_group_id" {
  description = "The ID of the EC2 Instance Security Group."
  value       = aws_security_group.ec2.id
}



# outputs.tf (Add this output)

output "cloudwatch_dashboard_name" {
  description = "The name of the CloudWatch Dashboard."
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

