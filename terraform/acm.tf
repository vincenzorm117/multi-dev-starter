
resource "aws_acm_certificate" "cert" {
  for_each          = local.domains
  domain_name       = each.value
  validation_method = "DNS"
  subject_alternative_names = [
    "*.${each.value}",
  ]
}

