

resource "aws_route53_zone" "main" {
  for_each = local.domains
  name     = each.key
}
