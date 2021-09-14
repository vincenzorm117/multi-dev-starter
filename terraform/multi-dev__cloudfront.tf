

resource "aws_cloudfront_origin_access_identity" "multi" {
  for_each = local.static_sites
  comment  = "Cloudfront OAI for ${each.value.hostname} multi dev environment."
}

resource "aws_cloudfront_distribution" "multi" {
  for_each = local.static_sites

  origin {
    origin_id   = "origin-multi--${each.value.hostname}"
    domain_name = aws_s3_bucket.multi[each.key].bucket_regional_domain_name

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.multi[each.key].cloudfront_access_identity_path
    }
  }

  enabled             = true
  default_root_object = "index.html"

  custom_error_response {
    error_code            = "404"
    error_caching_min_ttl = "300"
    response_code         = "200"
    response_page_path    = "/index.html"
  }

  lifecycle {
    ignore_changes = [aliases]
  }

  price_class = "PriceClass_100"

  default_cache_behavior {
    target_origin_id = "origin-multi--${each.value.hostname}"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    compress         = true

    forwarded_values {
      query_string = true
      cookies {
        forward = "none"
      }
      headers = ["Host"]
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400    # 1 day
    max_ttl                = 31536000 # 1 year

    lambda_function_association {
      event_type   = "origin-request"
      lambda_arn   = aws_lambda_function.multi.qualified_arn
      include_body = false
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE"]
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cert[local.static_site_domains_to_root_domain[each.value.hostname]].arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

}
