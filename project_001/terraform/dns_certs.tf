# dns_certs.tf

# --- Get Existing Route 53 Hosted Zone ---
# Assumes you have a Hosted Zone for pratiksontakke.art in Route 53
data "aws_route53_zone" "primary" {
  name         = "pratiksontakke.art." # Note the trailing dot
  private_zone = false
}

# --- Request ACM Certificate ---
# Request certificate for the API subdomain and potentially the root domain for CloudFront
resource "aws_acm_certificate" "main" {
  domain_name       = "pratiksontakke.art"
  subject_alternative_names = [
      "api.pratiksontakke.art"
      # Add others if needed, e.g., "*.pratiksontakke.art" for wildcard
    ]
  validation_method = "DNS" # Use DNS validation with Route 53

  tags = {
    Name        = "${var.project_name}-Certificate"
    Environment = var.environment
    Terraform   = "true"
  }

  lifecycle {
    create_before_destroy = true # Prevent outages if cert needs replacement
  }
}

# --- Create DNS Validation Records ---
# Creates the CNAME records in Route 53 that ACM requires to prove domain ownership
resource "aws_route53_record" "cert_validation" {
  # Create one validation record for each domain name in the certificate request
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name    = dvo.resource_record_name
      record  = dvo.resource_record_value
      type    = dvo.resource_record_type
    }
  }

  allow_overwrite = true # Useful if re-running validation
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.primary.zone_id
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
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "api.pratiksontakke.art"
  type    = "A" # Use 'A' record for Alias to ALB

  alias {
    name                   = aws_lb.main.dns_name # Points to the ALB DNS Name
    zone_id                = aws_lb.main.zone_id  # ALB's Hosted Zone ID
    evaluate_target_health = true                # Route traffic based on ALB health
  }
}

# A Record for the root domain pointing to the CloudFront distribution
resource "aws_route53_record" "root" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "pratiksontakke.art"
  type    = "A" # Use 'A' record for Alias to CloudFront

  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name # Points to CF Domain
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id # CF's Hosted Zone ID
    evaluate_target_health = false # Standard for CloudFront aliases
  }
}

# Optional: CNAME for www pointing to root (if desired)
resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "www.pratiksontakke.art"
  type    = "CNAME"
  ttl     = 300
  records = [aws_route53_record.root.name]
}