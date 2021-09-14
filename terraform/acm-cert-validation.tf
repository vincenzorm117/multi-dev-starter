locals {
  cert_dvos = flatten([
    for domain, cert in aws_acm_certificate.cert : [
      for dvo in cert.domain_validation_options : {
        root_domain = cert.domain_name
        domain_name = dvo.domain_name
        name        = dvo.resource_record_name
        record      = dvo.resource_record_value
        type        = dvo.resource_record_type
      }
    ]
  ])
}


resource "aws_acm_certificate_validation" "cert" {
  for_each = {
    for dvo in local.cert_dvos : "${dvo.root_domain}-${dvo.domain_name}" => dvo
  }
  certificate_arn         = aws_acm_certificate.cert[each.value.root_domain].arn
  validation_record_fqdns = [aws_route53_record.cert_validation[each.key].fqdn]
}



resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in local.cert_dvos : "${dvo.root_domain}-${dvo.domain_name}" => dvo
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main[each.value.root_domain].zone_id
}
