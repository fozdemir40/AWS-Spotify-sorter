terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }

  required_version = "~> 1.0"
}

provider "aws" { # The provider for this terraform application
  region = var.aws_region
}

resource "random_pet" "lambda_bucket_name" { # random_pet = generated a random pet name
  prefix = "spotify-sorter" # The string before random pet name
  length = 4 # Length of pet name
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = random_pet.lambda_bucket_name.id # Set the bucket with created name

  force_destroy = true
}

data "archive_file" "lambda_app"{ # Uploads the compiled application to the bucket.
  type = "zip"

  source_dir = "${path.module}/spotify_lambda"  # The source for function
  output_path = "${path.module}/spotify_lambda.zip" #  The output for function
}

resource "aws_s3_object" "lambda_app" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key = "spotify_lambda.zip"
  source = data.archive_file.lambda_app.output_path

  etag = filemd5(data.archive_file.lambda_app.output_path)
}

resource "aws_lambda_function" "spotify_sorter"{  # Configures the lambda function
  function_name = "SpotifySorter"

  s3_bucket = aws_s3_bucket.lambda_bucket.id  # Uses the S3 bucket
  s3_key = aws_s3_object.lambda_app.key

  runtime = "python3.9" # The runtime
  handler = "main.sorter" # finding the handler

  source_code_hash = data.archive_file.lambda_app.output_base64sha256 #  This defines if the code has changed. which lets lambda know if there is a new version

  role = aws_iam_role.lambda_exec.arn # Grants the function permissions.
}

resource "aws_cloudwatch_log_group" "spotify_sorter" {
  name = "/aws/lambda/${aws_lambda_function.spotify_sorter.function_name}" #  Location for log space

  retention_in_days = 30 #  Deletes the logs after 30 days.
}

resource "aws_iam_role" "lambda_exec" { # Defines the IAM role that allows lambda to access resources in AWS account
  name = "spotify_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" { # Attaches a policy IAM role.
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" # This specific role is an AWS managed policy that allows Lambda to write to CloudWatch
  role       = aws_iam_role.lambda_exec.name
}

resource "aws_apigatewayv2_api" "lambda" { # Creates API Gateway, sets name and protocol
  name          = "spotify_lambda_gw"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda" { # For settings stages in api gateway
  api_id = aws_apigatewayv2_api.lambda.id

  name        = "spotify_lambda_stage"
  auto_deploy = true

  access_log_settings { # with access logging enabled
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}

resource "aws_apigatewayv2_integration" "spotify_sorter_api" { # Configuring to let apiGateway use lambda function
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.spotify_sorter.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "spotify_sorter" { # Maps an HTTP request to a target
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "POST /sorting" # matches any requests matching the path
  target    = "integrations/${aws_apigatewayv2_integration.spotify_sorter_api.id}" # A target matching 'integrations/ID' maps to a Lambda integration with the given ID
}

resource "aws_cloudwatch_log_group" "api_gw" { # Defines a log group to store access logs
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"

  retention_in_days = 30 # Deletes after 30 days
}

resource "aws_lambda_permission" "api_gw" { # Gives permissions
  statement_id  = "AllowExecutionFromAPIGateway" # Gives API Gateway permission
  action        = "lambda:InvokeFunction" # permission to invoke Lambda function
  function_name = aws_lambda_function.spotify_sorter.function_name # name of function
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}