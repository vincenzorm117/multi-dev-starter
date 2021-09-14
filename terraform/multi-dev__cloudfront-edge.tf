


################################################
# Lambda function - Cloudfront Edge Router


data "archive_file" "edge" {
  type        = "zip"
  source_dir  = "../lambdas/cloudfront_edge"
  output_path = "../lambdas/cloudfront_edge.zip"
}


resource "aws_lambda_function" "multi" {
  function_name = "${var.team}-cloudfront-edge--multi"
  role          = aws_iam_role.multi.arn
  handler       = "index.handler"

  filename         = "../lambdas/cloudfront_edge.zip"
  source_code_hash = data.archive_file.edge.output_base64sha256

  runtime = "nodejs14.x"
  publish = true
}


############################################################
# Environment variables as a JSON file for Lambda@Edge
#   - Lambda@Edge functions don't accept environment variables per the restrictions:
#     https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/edge-functions-restrictions.html#lambda-requirements-lambda-function-configuration
resource "local_file" "multi" {
  filename = "../lambdas/cloudfront_edge/config.json"
  content = jsonencode({
    domainToS3 = {
      for site in var.static_sites : site.hostname => aws_s3_bucket.multi[site.hostname].bucket_domain_name
    }
  })
}




############################################################
# Role and permissions for AWS to fire off Lambda function

resource "aws_iam_role" "multi" {
  name               = "${var.team}-cloudfront-edge--multi"
  assume_role_policy = data.aws_iam_policy_document.multi.json
}

resource "aws_iam_role_policy_attachment" "multi_execution_role" {
  role       = aws_iam_role.multi.name
  policy_arn = aws_iam_policy.multi.arn
}


data "aws_iam_policy_document" "multi" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = [
        "lambda.amazonaws.com",
        "edgelambda.amazonaws.com"
      ]
    }
    effect = "Allow"
  }
}

############################################################ 
# Permissions for Lambda function logging to CloudWatch

resource "aws_iam_policy" "multi" {
  name        = "${var.team}-LambdaEdgeMultiLogging"
  description = "Enable CloudFront Edge lambda function logging."

  policy = data.aws_iam_policy_document.edge-multi-logging.json
}

data "aws_iam_policy_document" "edge-multi-logging" {

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

}

