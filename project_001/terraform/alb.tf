# alb.tf

# --- Security Group for Application Load Balancer ---
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-ALB-SG"
  description = "Allow HTTP/HTTPS inbound traffic to ALB and all outbound"
  vpc_id      = aws_vpc.main.id # Reference the VPC created in network.tf

  # Ingress Rule: Allow HTTP from anywhere
  ingress {
    description      = "Allow HTTP traffic from anywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"] # Allow from any IPv4 address
    ipv6_cidr_blocks = ["::/0"]     # Allow from any IPv6 address
  }

  # Ingress Rule: Allow HTTPS from anywhere (Placeholder for later)
  # ingress {
  #   description      = "Allow HTTPS traffic from anywhere"
  #   from_port        = 443
  #   to_port          = 443
  #   protocol         = "tcp"
  #   cidr_blocks      = ["0.0.0.0/0"]
  #   ipv6_cidr_blocks = ["::/0"]
  # }

  # Egress Rule: Allow all outbound traffic
  # Thinking: ALB needs to connect to targets (EC2 instances) in private subnets for health checks and traffic forwarding.
  # Allowing all outbound is often simplest for ALBs. Can be restricted if necessary but adds complexity.
  egress {
    from_port        = 0 # All ports
    to_port          = 0
    protocol         = "-1" # All protocols
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "${var.project_name}-ALB-SG"
    Environment = var.environment
    Terraform   = "true"
  }
}

# --- Application Load Balancer ---
resource "aws_lb" "main" {
  name               = "${var.project_name}-ALB"
  internal           = false # false = internet-facing
  load_balancer_type = "application"

  # Security Group defined above
  security_groups = [aws_security_group.alb.id]

  # Subnets: Must be public subnets for internet-facing ALB. Use IDs from network.tf output.
  # Thinking: Spanning multiple AZs makes the ALB highly available.
  subnets = aws_subnet.public[*].id # Reference the public subnet resources directly

  enable_deletion_protection = false # Set to true for production

  tags = {
    Name        = "${var.project_name}-ALB"
    Environment = var.environment
    Terraform   = "true"
  }
}

# alb.tf (Modify the aws_lb_target_group.app resource)

resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-TG"
  # CHANGE: Update port to match the application's listening port
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/" # Or specific health check path like "/healthz"
    protocol            = "HTTP"
    # CHANGE: Ensure health check also uses the application port
    port                = "traffic-port" # This means use the 'port' defined above (3000)
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200" # Often just check for 200 OK on health endpoints
  }

  tags = {
    Name        = "${var.project_name}-TG"
    Environment = var.environment
    Terraform   = "true"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Listener remains listening on port 80, forwarding to the TG which now connects to port 3000 on targets
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80 # Users connect to the ALB on port 80 (or 443 later)
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn # Forward to the TG defined above
  }
}


# alb.tf (Add HTTPS Listener, Modify HTTP Listener)

# --- ALB Listener for HTTPS Traffic ---
resource "aws_lb_listener" "https" {
  # Only create this listener if an ACM certificate ARN is provided
  count = var.acm_certificate_arn != "" ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08" # Use a recommended security policy
  certificate_arn   = var.acm_certificate_arn    # Reference the variable

  # Default Action: Forward to the same application target group
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# --- Modify existing HTTP Listener to redirect to HTTPS ---
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  # Default Action: Redirect HTTP to HTTPS if HTTPS listener is enabled
  # Otherwise, keep forwarding directly to the target group (for testing without HTTPS)
  default_action {
    type = var.acm_certificate_arn != "" ? "redirect" : "forward"

    # Redirect configuration (only applies if type is "redirect")
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301" # Permanent redirect
    }

    # Target group ARN (only applies if type is "forward")
    target_group_arn = var.acm_certificate_arn != "" ? null : aws_lb_target_group.app.arn
  }
}

# Modify ALB Security Group to allow HTTPS inbound
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-ALB-SG"
  description = "Allow HTTP/HTTPS inbound traffic to ALB and all outbound"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "Allow HTTP traffic" # Keep allowing HTTP for redirect purpose
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # Add Ingress Rule: Allow HTTPS from anywhere
  ingress {
    description      = "Allow HTTPS traffic"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "${var.project_name}-ALB-SG"
    Environment = var.environment
    Terraform   = "true"
  }
}