provider "aws" {
  region = "us-east-1"
}

variable "myregion" {
  default = "us-east-1"
}

variable "accountId" {
  default = "291660391595"
}

variable "function_name" {
  default = "Sample-Flask-App"
}

variable "handler" {
  default = "my_python_file.app"
}

variable "runtime" {
  default = "python3.6"
}

# API Gateway
resource "aws_api_gateway_rest_api" "api" {
  name = "sample-flask-api"
}

resource "aws_api_gateway_resource" "proxy_resource" {
  path_part   = "{proxy+}"
  parent_id   = "${aws_api_gateway_rest_api.api.root_resource_id}"
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
}

resource "aws_api_gateway_method" "method" {
  rest_api_id   = "${aws_api_gateway_rest_api.api.id}"
  resource_id   = "${aws_api_gateway_resource.proxy_resource.id}"
  http_method   = "ANY"
  authorization = "NONE"
}

#Response are needed for COORS
resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.proxy_resource.id}"
  #http_method = "${aws_api_gateway_method.options_method.http_method}"
  http_method = "${aws_api_gateway_method.method.http_method}"
  status_code = "200"

  response_models = {
     "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration" "integration" {
  rest_api_id             = "${aws_api_gateway_rest_api.api.id}"
  resource_id             = "${aws_api_gateway_resource.proxy_resource.id}"
  http_method             = "${aws_api_gateway_method.method.http_method}"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.lambda.invoke_arn}"
}


# Lambda Execute Permission from API Gateway
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.lambda.function_name}"
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${var.myregion}:${var.accountId}:${aws_api_gateway_rest_api.api.id}/*/${aws_api_gateway_method.method.http_method}${aws_api_gateway_resource.proxy_resource.path}"

  depends_on = [
    "aws_api_gateway_rest_api.api",
    "aws_api_gateway_resource.proxy_resource",
  ]
}

#Deployment
resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  stage_name  = "test"

  depends_on = [ "aws_api_gateway_integration.integration", "aws_lambda_permission.apigw_lambda" ]
}

#Lambda Layer
resource "aws_lambda_layer_version" "lambda_layer" {
  filename   = "python_libs.zip"
  layer_name = "python_dependencies"

  compatible_runtimes = ["python3.6"]

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda.zip"))}"
  source_code_hash = "${filebase64sha256("python_libs.zip")}"
}

#Lambda Function
resource "aws_lambda_function" "lambda" {
  role             = "${aws_iam_role.lambda_exec_role.arn}"
  handler          = "${var.handler}"
  runtime          = "${var.runtime}"
  function_name    = "${var.function_name}"
  filename         = "sample-flask.zip"

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda.zip"))}"
  source_code_hash = "${filebase64sha256("sample-flask.zip")}"

  #Layers
  layers = ["${aws_lambda_layer_version.lambda_layer.arn}"]
}

# IAM Role for Lamba Function
resource "aws_iam_role" "lambda_exec_role" {
  name        = "lambda_exec"
  path        = "/"
  description = "Allows Lambda Function to call AWS services on your behalf."

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}