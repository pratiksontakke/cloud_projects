# network.tf

# --- VPC ---
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block

  # Enable DNS features - essential for resolving AWS resource hostnames within the VPC
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project_name}-VPC"
    Environment = var.environment
    Terraform   = "true"
  }
}

# --- Subnets ---
# Logic: Create 'num_azs' public subnets, one in each selected AZ.
# cidrsubnet function calculates non-overlapping CIDR blocks for each subnet.
# Example: For 10.0.0.0/16, newbits=8 creates /24 subnets.
# Netnum 1 => 10.0.1.0/24, Netnum 2 => 10.0.2.0/24, etc.
resource "aws_subnet" "public" {
  count             = var.num_azs
  vpc_id            = aws_vpc.main.id
  # Use cidrsubnet(prefix, newbits, netnum)
  cidr_block        = cidrsubnet(var.vpc_cidr_block, 8, count.index + 1) # e.g., 10.0.1.0/24, 10.0.2.0/24, ...
  availability_zone = data.aws_availability_zones.available.names[count.index]

  # Enable auto-assigning public IPs for instances launched directly into this subnet (useful for testing, bastion hosts, not strictly needed for ALB)
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-PublicSubnet-${data.aws_availability_zones.available.names[count.index]}"
    Tier        = "Public"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Logic: Create 'num_azs' private subnets, one in each selected AZ.
# Use a different netnum range in cidrsubnet to avoid collision with public subnets.
resource "aws_subnet" "private" {
  count             = var.num_azs
  vpc_id            = aws_vpc.main.id
  # Start netnum range higher to avoid overlap (e.g., 101)
  cidr_block        = cidrsubnet(var.vpc_cidr_block, 8, count.index + 101) # e.g., 10.0.101.0/24, 10.0.102.0/24, ...
  availability_zone = data.aws_availability_zones.available.names[count.index]

  # Instances in private subnets should NOT get public IPs by default
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.project_name}-PrivateSubnet-${data.aws_availability_zones.available.names[count.index]}"
    Tier        = "Private"
    Environment = var.environment
    Terraform   = "true"
  }
}

# --- Gateways ---
# Logic: Internet Gateway allows communication between VPC and internet. Only one needed per VPC.
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-IGW"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Logic: NAT Gateway allows instances in private subnets to initiate outbound connections
# to the internet (e.g., for updates) but prevents inbound connections from the internet.
# Requires an Elastic IP (static public IP). Placed in a PUBLIC subnet.
# For higher availability, could create one per AZ, but starting with one for simplicity/cost.
resource "aws_eip" "nat" {
  # depends_on is useful if AWS provider has issues inferring dependency for VPC EIPs
  # depends_on = [aws_internet_gateway.gw] # Explicit dependency if needed
  domain   = "vpc" # Required for EIPs used with NAT Gateways

  tags = {
    Name        = "${var.project_name}-NAT-EIP"
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_nat_gateway" "gw" {
  allocation_id = aws_eip.nat.id
  # Place the NAT Gateway in the first public subnet
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name        = "${var.project_name}-NAT-GW-${data.aws_availability_zones.available.names[0]}" # Tag with AZ
    Environment = var.environment
    Terraform   = "true"
  }

  # Explicit dependency on the IGW being created first
  depends_on = [aws_internet_gateway.gw]
}

# --- Route Tables ---
# Logic: Public Route Table directs internet-bound traffic (0.0.0.0/0) from public subnets to the Internet Gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0" # Represents all IPv4 traffic
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name        = "${var.project_name}-PublicRouteTable"
    Tier        = "Public"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Logic: Associate each public subnet with the public route table.
resource "aws_route_table_association" "public" {
  count          = var.num_azs
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Logic: Private Route Table directs internet-bound traffic (0.0.0.0/0) from private subnets to the NAT Gateway.
# Using a single private route table associated with all private subnets for simplicity with one NAT GW.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.gw.id # Point to the NAT Gateway
  }

  tags = {
    Name        = "${var.project_name}-PrivateRouteTable"
    Tier        = "Private"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Logic: Associate each private subnet with the private route table.
resource "aws_route_table_association" "private" {
  count          = var.num_azs
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}