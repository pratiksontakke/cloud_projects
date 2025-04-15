# alb.tf

# --- Security Group for Application Load Balancer ---
# RETAIN THIS VERSION (allows both HTTP for redirect and HTTPS)
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-ALB-SG"
  description = "Allow HTTP/HTTPS inbound traffic to ALB and all outbound"
  vpc_id      = aws_vpc.main.id # Assumes aws_vpc.main is defined in network.tf

  ingress {
    description      = "Allow HTTP traffic (for redirect)"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

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

# --- Application Load Balancer ---
# RETAIN THIS
resource "aws_lb" "main" {
  name               = "${var.project_name}-ALB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  # Assumes aws_subnet.public is defined in network.tf
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false # Consider true for production

  tags = {
    Name        = "${var.project_name}-ALB"
    Environment = var.environment
    Terraform   = "true"
  }
}

# --- Target Group for Application Instances ---
# RETAIN THIS (Ensure port 3000 matches your app)
resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-TG"
  port        = var.app_port # Application listens on this port inside the EC2 instance
  protocol    = "HTTP" # ALB talks HTTP to the instance
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/health" # Or your app's health check path (e.g., "/health")
    protocol            = "HTTP"
    port                = "traffic-port" # Health check uses the target group port (3000)
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200" # Expect HTTP 200 OK for healthy
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

# --- ALB Listener for HTTPS Traffic (Conditional) ---
# RETAIN THIS
resource "aws_lb_listener" "https" {
  # Only create this listener if an ACM certificate ARN is provided
  count = var.acm_certificate_arn != "" ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08" # Standard security policy
  certificate_arn   = var.acm_certificate_arn    # Reference the variable

  # Default Action: Forward HTTPS traffic to the application target group
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# --- ALB Listener for HTTP Traffic (Conditional Redirect/Forward) ---
# RETAIN THIS VERSION
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  # Default Action: Redirect HTTP to HTTPS if HTTPS listener is enabled (cert provided),
  # otherwise, forward HTTP directly to the target group.
  default_action {
    type = var.acm_certificate_arn != "" ? "redirect" : "forward"

    # Redirect config (only applies if type is "redirect")
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301" # Permanent redirect
    }

    # Target group ARN (only applies if type is "forward")
    # Set target_group_arn ONLY when forwarding, otherwise it conflicts with redirect block.
    target_group_arn = var.acm_certificate_arn != "" ? null : aws_lb_target_group.app.arn
  }
}