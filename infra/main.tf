# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Local paths for Lambda artifacts (store zips under each lambda directory)
locals {
  hello_zip_path             = "${abspath(path.module)}/../lambda/hello/hello_function.zip"
  auth_cognito_test_zip_path = "${abspath(path.module)}/../lambda/auth_cognito_test/auth_cognito_test_function.zip"
}

# Archive Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${abspath(path.module)}/../lambda/hello/app.py"
  output_path = local.hello_zip_path
}

# Package Lambda Auth Cognito Test with dependencies
resource "null_resource" "auth_cognito_test_package" {
  triggers = {
    app_code     = filebase64sha256("${abspath(path.module)}/../lambda/auth_cognito_test/app.py")
    requirements = filebase64sha256("${abspath(path.module)}/../lambda/auth_cognito_test/requirements.txt")
    # If the local zip was deleted, force re-run on next apply.
    zip_sha256 = try(filesha256(local.auth_cognito_test_zip_path), "")
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail && \
      TEMP_DIR=$(mktemp -d) && \
      OUT_ZIP="${abspath(path.module)}/../lambda/auth_cognito_test/auth_cognito_test_function.zip" && \
      cp "${abspath(path.module)}/../lambda/auth_cognito_test/app.py" "$TEMP_DIR/" && \
      pip install -r "${abspath(path.module)}/../lambda/auth_cognito_test/requirements.txt" -t "$TEMP_DIR" --quiet && \
      cd "$TEMP_DIR" && \
      zip -r "$OUT_ZIP" . -q && \
      rm -rf "$TEMP_DIR"
    EOT
  }
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

  lifecycle {
    precondition {
      condition     = fileexists("${abspath(path.module)}/../lambda/hello/app.py")
      error_message = "Missing Lambda source: lambda/hello/app.py"
    }
  }

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

# ============================================
# Cognito Resources
# ============================================

# Cognito User Pool
resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-user-pool"

  # Password policy
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = false
  }

  # User attributes
  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true
  }

  schema {
    name                = "name"
    attribute_data_type = "String"
    required            = false
    mutable             = true
  }

  # Auto verify email
  auto_verified_attributes = ["email"]

  # NOTE:
  # Cognito User Pool schema cannot be modified after creation.
  # If schema blocks change (or provider reads defaults differently), apply will fail.
  # Keep schema applied at create-time, and ignore later diffs.
  lifecycle {
    ignore_changes = [schema]
  }

  tags = local.common_tags
}

# Cognito User Pool Client
resource "aws_cognito_user_pool_client" "main" {
  name         = "${var.project_name}-client"
  user_pool_id = aws_cognito_user_pool.main.id

  # OAuth settings
  generate_secret                      = false
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  allowed_oauth_flows_user_pool_client = true
  supported_identity_providers         = ["COGNITO"]

  # Callback URLs (adjust as needed)
  callback_urls = ["http://localhost:3000/callback"]
  logout_urls   = ["http://localhost:3000/logout"]

  # Token validity
  id_token_validity      = 60
  access_token_validity  = 60
  refresh_token_validity = 30

  # NOTE:
  # Provider v5+ defaults access/id token units to "hours".
  # 60 without units becomes 60 hours and exceeds the 24h limit.
  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}

# ============================================
# Auth Cognito Test Lambda Function (Unified)
# ============================================

# CloudWatch Log Group for Auth Cognito Test
resource "aws_cloudwatch_log_group" "auth_cognito_test_logs" {
  name              = "/aws/lambda/${var.project_name}-auth-cognito-test"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

# Unified Lambda function (Authorizer + Public + Protected endpoints)
resource "aws_lambda_function" "auth_cognito_test" {
  function_name = "${var.project_name}-auth-cognito-test"
  role          = aws_iam_role.lambda_role.arn
  handler       = "app.lambda_handler"
  runtime       = "python3.12"
  filename      = local.auth_cognito_test_zip_path
  # NOTE:
  # The zip is created by a local-exec (null_resource) at apply time, so it may not
  # exist during `terraform plan`. Hash the real inputs instead to keep plan working
  # and still trigger updates when code/deps change.
  source_code_hash = base64sha256(join("", [
    filesha256("${abspath(path.module)}/../lambda/auth_cognito_test/app.py"),
    filesha256("${abspath(path.module)}/../lambda/auth_cognito_test/requirements.txt"),
  ]))

  timeout = 30

  lifecycle {
    precondition {
      condition     = fileexists("${abspath(path.module)}/../lambda/auth_cognito_test/app.py")
      error_message = "Missing Lambda source: lambda/auth_cognito_test/app.py"
    }
    precondition {
      condition     = fileexists("${abspath(path.module)}/../lambda/auth_cognito_test/requirements.txt")
      error_message = "Missing requirements: lambda/auth_cognito_test/requirements.txt"
    }
  }

  environment {
    variables = {
      COGNITO_USER_POOL_ID = aws_cognito_user_pool.main.id
      # NOTE: AWS_REGION is a reserved environment variable key in Lambda.
      # Use an application-specific key instead.
      APP_AWS_REGION = var.aws_region
    }
  }

  depends_on = [
    null_resource.auth_cognito_test_package,
    aws_iam_role_policy.lambda_logs,
    aws_cloudwatch_log_group.auth_cognito_test_logs
  ]

  tags = local.common_tags
}

# ============================================
# API Gateway Authorizer
# ============================================

# Lambda Authorizer for API Gateway (using unified function)
resource "aws_apigatewayv2_authorizer" "lambda_authorizer" {
  api_id          = aws_apigatewayv2_api.hello_vpc_api.id
  authorizer_type = "REQUEST"
  # HTTP API REQUEST authorizer requires payload format version.
  # This project currently returns an IAM policy (payload format 1.0).
  authorizer_payload_format_version = "1.0"
  authorizer_uri                    = aws_lambda_function.auth_cognito_test.invoke_arn
  identity_sources                  = ["$request.header.Authorization"]
  name                              = "${var.project_name}-lambda-authorizer"
}

# Lambda permission for Authorizer
resource "aws_lambda_permission" "authorizer_invoke" {
  statement_id  = "AllowAPIGatewayInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth_cognito_test.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.hello_vpc_api.execution_arn}/authorizers/${aws_apigatewayv2_authorizer.lambda_authorizer.id}"
}

# ============================================
# API Gateway Routes for Auth Endpoints
# ============================================

# API Gateway integration for unified Lambda (used for both public and protected)
resource "aws_apigatewayv2_integration" "auth_cognito_test_integration" {
  api_id = aws_apigatewayv2_api.hello_vpc_api.id

  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.auth_cognito_test.invoke_arn
  integration_method = "POST"
}

# API Gateway route for Public endpoint
resource "aws_apigatewayv2_route" "public_route" {
  api_id    = aws_apigatewayv2_api.hello_vpc_api.id
  route_key = "GET /public"
  target    = "integrations/${aws_apigatewayv2_integration.auth_cognito_test_integration.id}"
}

# API Gateway route for Protected endpoint (with authorizer)
resource "aws_apigatewayv2_route" "protected_route" {
  api_id             = aws_apigatewayv2_api.hello_vpc_api.id
  route_key          = "GET /protected"
  target             = "integrations/${aws_apigatewayv2_integration.auth_cognito_test_integration.id}"
  authorizer_id      = aws_apigatewayv2_authorizer.lambda_authorizer.id
  authorization_type = "CUSTOM"
}

# Lambda permission for unified function
resource "aws_lambda_permission" "auth_cognito_test_invoke" {
  statement_id  = "AllowAPIGatewayInvokeAuthCognitoTest"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth_cognito_test.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.hello_vpc_api.execution_arn}/*/*"
}
