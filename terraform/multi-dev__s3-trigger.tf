

################################################
# Lambda Role

resource "aws_iam_role" "multi-dev-deploy" {
  name               = "${var.team}-multi-dev-deploy"
  assume_role_policy = data.aws_iam_policy_document.multi-dev-deploy-role.json
}

data "aws_iam_policy_document" "multi-dev-deploy-role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    effect = "Allow"
  }
}


################################################
# Lambda permissions

resource "aws_iam_role_policy_attachment" "multi-dev-deploy" {
  role       = aws_iam_role.multi-dev-deploy.name
  policy_arn = aws_iam_policy.multi-dev-deploy.arn
}

resource "aws_iam_policy" "multi-dev-deploy" {
  name        = "${var.team}-multi-dev-deploy"
  description = "Enable cloudfront invalidation, route53 record creation and cloudfront distribution updates."

  policy = data.aws_iam_policy_document.multi-dev-deploy.json
}


data "aws_iam_policy_document" "multi-dev-deploy" {

  statement {
    sid = "Logging"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    sid = "CloudfrontActions"
    actions = [
      "cloudfront:GetDistribution",
      "cloudfront:GetDistributionConfig",
      "cloudfront:CreateInvalidation",
      "cloudfront:UpdateDistribution",
      "cloudfront:CreateInvalidation",
      "cloudfront:GetInvalidation",
    ]
    effect = "Allow"
    resources = [
      for cf in aws_cloudfront_distribution.multi : cf.arn
    ]
  }

  statement {
    sid = "Route53RecordCreation"
    actions = [
      "route53:ChangeResourceRecordSets",
    ]
    effect = "Allow"
    resources = [
      for d in aws_route53_zone.main : "arn:aws:route53:::hostedzone/${d.zone_id}"
    ]
  }
}

# Allows S3 buckets to invoke lambda
resource "aws_lambda_permission" "multi-dev--allow_bucket_lambda_alias" {
  for_each      = local.static_sites
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.multi-dev-deploy.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.multi[each.key].arn
}





################################################
# Lambda Definition

data "archive_file" "multi-dev-deploy" {
  type        = "zip"
  source_dir  = "../lambdas/multi_dev_deploy"
  output_path = "../lambdas/multi_dev_deploy.zip"
}


resource "aws_lambda_function" "multi-dev-deploy" {
  function_name = "${var.team}-multi-dev-deploy"
  description   = "For new dev environment deploy, after S3 triggers this function, an A record is created and cloudfront is updated with the record."
  role          = aws_iam_role.multi-dev-deploy.arn
  handler       = "index.handler"

  filename         = "../lambdas/multi_dev_deploy.zip"
  source_code_hash = data.archive_file.multi-dev-deploy.output_base64sha256

  runtime = "nodejs14.x"
  publish = true

  timeout = 300

  environment {
    variables = merge(
      {
        # Cloudfront ID => S3 bucket name
        for s in local.static_sites : aws_cloudfront_distribution.multi[s.hostname].id => "cf-${aws_s3_bucket.multi[s.hostname].bucket}"
        }, {
        # Hosted Zone Ids => S3 bucket names prefixed with 'hz-'
        for s in var.static_sites : aws_route53_zone.main[regex("[^.]+.[^.]+$", s.hostname)].zone_id => "hz-${aws_s3_bucket.multi[s.hostname].bucket}"
        }, {
        # Root domain => S3 bucket name
        for s in var.static_sites : replace(local.static_site_domains_to_root_domain[s.hostname], ".", "_") => "dns-${aws_s3_bucket.multi[s.hostname].bucket}"
        }, {
        "CLOUDFRONT_HOSTED_ZONE_ID" = "Z2FDTNDATAQYW2"
      }
    )
  }

}


################################################
# S3 Trigger

resource "aws_s3_bucket_notification" "multi-dev-deploy" {
  for_each = local.static_sites
  bucket   = aws_s3_bucket.multi[each.key].id

  lambda_function {
    # Fire Lambda only if the index.html file is updated
    lambda_function_arn = aws_lambda_function.multi-dev-deploy.arn
    events = [
      "s3:ObjectCreated:*",
      "s3:ObjectRemoved:*",
    ]
    filter_suffix = "index.html"
  }
}
