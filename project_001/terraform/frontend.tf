# frontend.tf

# --- S3 Bucket for Frontend Static Assets ---
resource "aws_s3_bucket" "frontend" {
  # Bucket names must be globally unique
  bucket = "${var.project_name}-${var.environment}-frontend-assets-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "${var.project_name}-FrontendAssets"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Random suffix to help ensure global bucket name uniqueness
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Block public access settings - enforce private bucket
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Ownership Controls - Required for ACLs/OAC settings
resource "aws_s3_bucket_ownership_controls" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  rule {
    object_ownership = "BucketOwnerEnforced" # Recommended: Disables ACLs, simplifies permissions
  }
}


# --- CloudFront Origin Access Control (OAC) ---
# Logic: Allows CloudFront to securely access the private S3 bucket contents.
resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.project_name}-${var.environment}-frontend-s3-oac"
  description                       = "OAC for ${var.project_name} frontend S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always" # Always sign requests to S3
  signing_protocol                  = "sigv4"  # Use Signature Version 4
}


# --- S3 Bucket Policy ---
# Logic: Grants the CloudFront OAC permission to GetObject from the bucket.
data "aws_iam_policy_document" "frontend_s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend.arn}/*"] # Allow access to all objects in the bucket

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    # Condition ensures only requests from the specific CloudFront distribution using the OAC are allowed
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      # Reference the CloudFront distribution ARN (we use a placeholder for now and will refer to the actual resource)
      values = ["arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${aws_cloudfront_distribution.frontend.id}"]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.frontend_s3_policy.json

  # Ensure OAC is created before applying the policy that references the distribution
  depends_on = [
    aws_cloudfront_origin_access_control.frontend,
    aws_cloudfront_distribution.frontend
  ]
}

# Get current AWS Account ID for ARNs
data "aws_caller_identity" "current" {}


# --- CloudFront Distribution ---
resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution for ${var.project_name} frontend"
  default_root_object = "index.html" # Serve index.html for root requests (e.g., /)
    # Add Aliases for custom domain
  aliases = [var.domain_name] # e.g., ["pratiksontakke.art"]

  restrictions {
    geo_restriction {
      # Set to 'none' if you don't want geo-restrictions (most common)
      # Other options: 'whitelist' or 'blacklist' (require 'locations' argument)
      restriction_type = "none"
      # locations = ["US", "CA", "GB", "DE"] # Only required if type is whitelist/blacklist
    }
  }

  # --- Origin Configuration ---
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name # Use regional domain name for S3 origin
    origin_id                = "S3-${aws_s3_bucket.frontend.id}"               # Unique ID for this origin
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id # Use OAC defined above
  }

  # --- Default Cache Behavior ---
  default_cache_behavior {
    target_origin_id       = "S3-${aws_s3_bucket.frontend.id}" # Matches origin_id above
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]      # Allow standard read methods
    cached_methods         = ["GET", "HEAD"]                 # Cache GET and HEAD requests
    viewer_protocol_policy = "redirect-to-https"           # Enforce HTTPS
    compress               = true                            # Enable gzip/brotli compression
    # Cache policy - use a managed policy for caching static content
    # Adjust TTLs as needed (e.g., shorter TTL during frequent updates)
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6" # Managed-CachingOptimized policy ID (check AWS docs for current ID/options)
    # Optional: Origin request policy - can forward headers, cookies, etc. (not usually needed for S3 static)
    # origin_request_policy_id = "..."
  }

  # --- Viewer Certificate ---
  # Use default CloudFront certificate for *.cloudfront.net domain
 # Use ACM certificate instead of default
 viewer_certificate {
    # Correctly references the validated certificate ARN from dns_certs.tf
    acm_certificate_arn = aws_acm_certificate_validation.main.certificate_arn # <-- CORRECT REFERENCE
    ssl_support_method  = "sni-only"        # Standard method
    minimum_protocol_version = "TLSv1.2_2021" # Recommended minimum TLS version
    # cloudfront_default_certificate = true # Ensure this is removed or false
  }

  # --- Other Settings ---
  price_class = "PriceClass_100" # Choose price class (e.g., PriceClass_100 = US/EU, PriceClass_All = Global)
  # Optional: Configure logging, WAF, etc.
  # logging_config { ... }
  # web_acl_id = aws_wafv2_web_acl.main.arn # If using WAF

  # Optional: Custom error response for SPAs (redirect 403/404 to index.html)
  # This allows React Router to handle client-side routing for paths that don't exist as files in S3
  custom_error_response {
    error_caching_min_ttl = 10
    error_code            = 403 # Forbidden (often occurs if object doesn't exist with OAC)
    response_code         = 200
    response_page_path    = "/index.html"
  }
  custom_error_response {
    error_caching_min_ttl = 10
    error_code            = 404 # Not Found
    response_code         = 200
    response_page_path    = "/index.html"
  }


  tags = {
    Name        = "${var.project_name}-Frontend-CF"
    Environment = var.environment
    Terraform   = "true"
  }

  # Ensure the bucket exists before creating the distribution
  depends_on = [aws_s3_bucket.frontend]
}