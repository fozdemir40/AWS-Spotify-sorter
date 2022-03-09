variable region {
  type        = string
  description = "Preferred AWS region to deploy resources"
  default     = "eu-west-1"
}

variable bucket {
  type        = string
  description = "Bucket name containing the lambda"
  default = "spotify-sorter-s3"
}

variable lambda_file {
  type        = string
  description = "Lambda file name"
  default = "lambda.zip"
}

variable lambda_function_name {
  type        = string
  description = "Lambda function name"
  default = "furkan-spotify-sorter"
}