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