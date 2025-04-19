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
  # Remove count - always create if using custom domain setup
  # count = var.acm_certificate_arn != "" ? 1 : 0 # REMOVE THIS LINE

  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  # Use the ARN from the validated certificate resource
  certificate_arn   = aws_acm_certificate_validation.main.certificate_arn # USE VALIDATED ARN

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  # Default Action: ALWAYS redirect to HTTPS in this setup
  default_action {
    type = "redirect" # CHANGE from conditional to always redirect

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }

    # target_group_arn is no longer needed here
    # target_group_arn = var.acm_certificate_arn != "" ? null : aws_lb_target_group.app.arn # REMOVE THIS LINE
  }
}