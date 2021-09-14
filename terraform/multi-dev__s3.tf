
resource "aws_s3_bucket" "multi" {
  for_each = local.static_sites

  bucket = "${var.team}-${replace(each.value.hostname, ".", "-")}--multi-dev"
  acl    = "private"

  versioning {
    enabled = false
  }
}

resource "aws_s3_bucket_policy" "multi_bucket_policy" {
  for_each = local.static_sites

  bucket = aws_s3_bucket.multi[each.key].id
  policy = data.aws_iam_policy_document.multi_bucket_policy[each.key].json
}


data "aws_iam_policy_document" "multi_bucket_policy" {
  for_each = local.static_sites
  statement {
    actions = ["s3:GetObject"]
    resources = [
      "${aws_s3_bucket.multi[each.key].arn}/*"
    ]

    principals {
      type = "AWS"
      identifiers = [
        aws_cloudfront_origin_access_identity.multi[each.key].iam_arn
      ]
    }
  }
}
