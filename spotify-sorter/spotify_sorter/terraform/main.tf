terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 3.8"
    }
  }
}

provider "aws" {
  region = var.region
}

data aws_iam_policy_document assume_role{
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = toset(["lambda.amazonaws.com"])
      type        = "Service"
    }
  }
}

resource aws_iam_role lambda{
  name = "spotify-sorter-lambda-${var.bucket}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource aws_iam_role_policy_attachment aws_lambda_cloudwatch {
  policy_arn         = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role               = aws_iam_role.lambda.name
}

resource aws_iam_role_policy_attachment aws_xray_write_only_access {
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
  role       = aws_iam_role.lambda.name
}

resource aws_iam_role_policy_attachment aws_s3_access {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

module lambda {
  source = "git::ssh://git@github.com/ConnectHolland/terraform-aws-lambda-function.git?ref=tags/0.2.1"

  filename = var.lambda_file
  bucketname = var.bucket
  source_code_hash = filebase64sha256("./spotify_lambda/lambda.zip")

  description = "Spotify sorter"
  function_name = var.lambda_function_name
  handler = "main.sorter"
  role_arn = aws_iam_role.lambda.arn
  runtime = "python3.9"
  enable_xray = true

  lambda_env_vars = {
    BUCKET = var.bucket
  }

  role_numbers = {LMB = 1, API = 1, LOG = 1}
  tagging_defaults = local.tagging_defaults
}

module authorizer {
  source = "git::ssh://git@github.com/ConnectHolland/terraform-aws-lambda-function.git?ref=tags/0.2.1"

  filename         = var.lambda_file
  bucketname       = var.bucket
  source_code_hash = filebase64sha256("./spotify_lambda/lambda.zip")

  description   = "Tutorial authorizer lambda"
  function_name = "${var.lambda_function_name}-authorizer"
  handler       = "authorizer.sorter"
  role_arn      = aws_iam_role.lambda.arn
  runtime       = "python3.9"
  enable_xray   = true

  lambda_env_vars = {
    BUCKET = var.bucket
  }

  role_numbers     = module.lambda.role_numbers
  tagging_defaults = local.tagging_defaults
}

module api_gateway {
  source = "git::ssh://git@github.com/ConnectHolland/terraform-aws-api-gateway.git?ref=tags/0.2.1"

  description            = "Spotify sorter API"
  name                   = "api-${var.bucket}"
  endpoint_types         = ["REGIONAL"]
  stage                  = "dev"
  paths                  = ["processing"]
  http_methods           = ["POST"]
  lambda_invoke_arn_list = [module.lambda.invoke_arn]

  CORS_allow_methods = "'OPTIONS,POST'"
  CORS_allow_origin  = "'*'"

  authorizer_type = "REQUEST"
  authorizer_uri  = module.authorizer.invoke_arn
  enable_xray     = true

  role_numbers     = module.authorizer.role_numbers
  tagging_defaults = local.tagging_defaults
}

resource aws_lambda_permission lambda {
  statement_id  = "AllowMyDemoAPIInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda.name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${module.api_gateway.execution_arn}/*/*/*"
}

resource aws_lambda_permission authorizer {
  statement_id  = "AllowMyDemoAPIInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.authorizer.name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${module.api_gateway.execution_arn}/*/*/*"
}