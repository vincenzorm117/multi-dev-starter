

resource "aws_iam_user" "syncer" {
  for_each = local.static_sites
  name     = "${var.team}-${each.key}"
  path     = "/${var.team}/syncer/"
}

resource "aws_iam_access_key" "syncer" {
  for_each = local.static_sites
  user     = aws_iam_user.syncer[each.key].name
}

resource "aws_iam_user_policy" "syncer" {
  for_each = local.static_sites
  name     = "${var.team}-syncer-${each.key}"
  user     = aws_iam_user.syncer[each.key].name

  policy = data.aws_iam_policy_document.syncer[each.key].json
}

data "aws_iam_policy_document" "syncer" {
  for_each = local.static_sites

  statement {
    sid = "S3SiteSync"
    actions = [
      "s3:ListObjectsV2",
      "s3:CopyObject",
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
      "s3:DeleteObjects",
      "s3:DeleteObject",
    ]
    effect = "Allow"
    resources = [
      aws_s3_bucket.multi[each.key].arn,
      "${aws_s3_bucket.multi[each.key].arn}/*",
    ]
  }

}


