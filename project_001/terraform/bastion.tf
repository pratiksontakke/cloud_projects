# bastion.tf

# --- Security Group for Bastion Host ---
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-Bastion-SG"
  description = "Allow SSH inbound from My IP and all outbound"
  vpc_id      = aws_vpc.main.id # Assumes aws_vpc.main defined in network.tf

  # Ingress: Allow SSH ONLY from your specific IP address
  ingress {
    description = "Allow SSH from My IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict access!
  }

  # Egress: Allow all outbound traffic
  # Bastion needs to connect to private instances (SSH), internet (updates), etc.
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "${var.project_name}-Bastion-SG"
    Environment = var.environment
    Terraform   = "true"
  }
}

# --- EC2 Instance for Bastion Host ---
resource "aws_instance" "bastion" {
  # AMI: Use the same Amazon Linux 2023 AMI as app servers (fetched by data source)
  ami           = data.aws_ami.latest_ami.id # Assumes data.aws_ami.latest_ami exists in compute.tf or similar
  instance_type = var.bastion_instance_type

  # Key Pair: Associate the existing key pair for SSH login
  key_name = var.ec2_key_name

  # Network: Place in the first public subnet
  subnet_id = aws_subnet.public[0].id # Assumes aws_subnet.public exists in network.tf

  # Security Group: Attach the Bastion SG
  vpc_security_group_ids = [aws_security_group.bastion.id]

  # Ensure it gets a public IP to be reachable
  associate_public_ip_address = true

  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name # <--- This line adds the profile


  tags = {
    Name        = "${var.project_name}-BastionHost"
    Environment = var.environment
    Terraform   = "true"
  }
}