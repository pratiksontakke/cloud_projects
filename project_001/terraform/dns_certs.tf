# dns_certs.tf

# --- Get Existing Route 53 Hosted Zone ---
# Assumes you have a Hosted Zone for pratiksontakke.art in Route 53
resource "aws_route53_zone" "primary" {
  name = var.domain_name # Use variable "pratiksontakke.art"

  tags = {
    Name        = "${var.project_name}-HostedZone"
    Environment = var.environment
    Terraform   = "true"
  }
}

# --- Request ACM Certificate ---
# Request certificate for the API subdomain and potentially the root domain for CloudFront
resource "aws_acm_certificate" "main" {
  domain_name       = var.domain_name # Use variable
  subject_alternative_names = [
      "${var.api_subdomain}.${var.domain_name}" # Construct using variables
    ]
  validation_method = "DNS"

  tags = {
    Name        = "${var.project_name}-Certificate"
    Environment = var.environment
    Terraform   = "true"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# --- Create DNS Validation Records ---
# Creates the CNAME records in Route 53 that ACM requires to prove domain ownership
# --- Create DNS Validation Records ---
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name    = dvo.resource_record_name
      record  = dvo.resource_record_value
      type    = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  # --- UPDATE Zone ID Reference ---
  zone_id         = aws_route53_zone.primary.zone_id # Use the RESOURCE ID
}

# --- Wait for Certificate Validation ---
# Ensures Terraform doesn't proceed until ACM confirms the certificate is validated and issued
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}


# --- Create DNS Records for Services ---

# A Record for the API subdomain pointing to the ALB
resource "aws_route53_record" "api" {
  # --- UPDATE Zone ID Reference ---
  zone_id = aws_route53_zone.primary.zone_id # Use the RESOURCE ID
  name    = "${var.api_subdomain}.${var.domain_name}" # Construct using variables
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# A Record for the root domain pointing to the CloudFront distribution
resource "aws_route53_record" "root" {
  # --- UPDATE Zone ID Reference ---
  zone_id = aws_route53_zone.primary.zone_id # Use the RESOURCE ID
  name    = var.domain_name # Use variable
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
    evaluate_target_health = false
  }
}

# Optional: CNAME for www pointing to root (if desired)
resource "aws_route53_record" "www" {
  # --- UPDATE Zone ID Reference ---
  zone_id = aws_route53_zone.primary.zone_id # Use the RESOURCE ID
  name    = "www.${var.domain_name}" # Construct using variable
  type    = "CNAME"
  ttl     = 300
  # Point to the root record's FQDN
  records = [aws_route53_record.root.name]
}