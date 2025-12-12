# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Archive Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/hello/app.py"
  output_path = "${path.module}/lambda_function.zip"
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM policy for Lambda basic execution (CloudWatch Logs)
resource "aws_iam_role_policy" "lambda_logs" {
  name = "${var.project_name}-lambda-logs"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.project_name}"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

# VPC resources (only if enable_vpc is true)
resource "aws_vpc" "lambda_vpc" {
  count = var.enable_vpc ? 1 : 0

  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-vpc"
    }
  )
}

# Private Subnet 1 (ap-northeast-1a)
resource "aws_subnet" "private_subnet_1" {
  count = var.enable_vpc ? 1 : 0

  vpc_id            = aws_vpc.lambda_vpc[0].id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-northeast-1a"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-private-subnet-1a"
    }
  )
}

# Private Subnet 2 (ap-northeast-1c)
resource "aws_subnet" "private_subnet_2" {
  count = var.enable_vpc ? 1 : 0

  vpc_id            = aws_vpc.lambda_vpc[0].id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-northeast-1c"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-private-subnet-1c"
    }
  )
}

# Security Group for Lambda (only if VPC is enabled)
resource "aws_security_group" "lambda_sg" {
  count = var.enable_vpc ? 1 : 0

  name        = "${var.project_name}-lambda-sg"
  description = "Security group for Lambda function"
  vpc_id      = aws_vpc.lambda_vpc[0].id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-lambda-sg"
    }
  )
}

# IAM policy for VPC access (only if VPC is enabled)
resource "aws_iam_role_policy" "lambda_vpc" {
  count = var.enable_vpc ? 1 : 0

  name = "${var.project_name}-lambda-vpc"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda function
resource "aws_lambda_function" "hello_vpc" {
  function_name    = var.project_name
  role             = aws_iam_role.lambda_role.arn
  handler          = "app.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  # VPC configuration (only if enable_vpc is true)
  dynamic "vpc_config" {
    for_each = var.enable_vpc ? [1] : []
    content {
      subnet_ids         = [aws_subnet.private_subnet_1[0].id, aws_subnet.private_subnet_2[0].id]
      security_group_ids = [aws_security_group.lambda_sg[0].id]
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_logs,
    aws_cloudwatch_log_group.lambda_logs
  ]

  tags = local.common_tags
}

# API Gateway HTTP API
resource "aws_apigatewayv2_api" "hello_vpc_api" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
  description   = "HTTP API for ${var.project_name} Lambda function"

  tags = local.common_tags
}

# API Gateway integration with Lambda
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id = aws_apigatewayv2_api.hello_vpc_api.id

  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.hello_vpc.invoke_arn
  integration_method = "POST"
}

# API Gateway route
resource "aws_apigatewayv2_route" "hello_route" {
  api_id    = aws_apigatewayv2_api.hello_vpc_api.id
  route_key = "GET /hello"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# API Gateway stage
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.hello_vpc_api.id
  name        = "$default"
  auto_deploy = true

  tags = local.common_tags
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello_vpc.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.hello_vpc_api.execution_arn}/*/*"
}
