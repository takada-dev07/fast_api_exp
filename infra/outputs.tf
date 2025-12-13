output "api_gateway_invoke_url" {
  description = "API Gateway Invoke URL for /hello endpoint"
  value       = "${aws_apigatewayv2_api.hello_vpc_api.api_endpoint}/hello"
}

output "api_gateway_base_url" {
  description = "API Gateway base URL"
  value       = aws_apigatewayv2_api.hello_vpc_api.api_endpoint
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.hello_vpc.function_name
}

output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.hello_vpc.arn
}

output "vpc_enabled" {
  description = "Whether VPC is enabled for Lambda"
  value       = var.enable_vpc
}

output "vpc_id" {
  description = "VPC ID (only if VPC is enabled)"
  value       = var.enable_vpc ? aws_vpc.lambda_vpc[0].id : null
}

# ============================================
# Cognito Outputs
# ============================================

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN"
  value       = aws_cognito_user_pool.main.arn
}

output "cognito_user_pool_client_id" {
  description = "Cognito User Pool Client ID"
  value       = aws_cognito_user_pool_client.main.id
}

output "cognito_user_pool_endpoint" {
  description = "Cognito User Pool endpoint"
  value       = aws_cognito_user_pool.main.endpoint
}

# ============================================
# Auth Cognito Test Lambda Outputs
# ============================================

output "lambda_auth_cognito_test_function_name" {
  description = "Auth Cognito Test Lambda function name"
  value       = aws_lambda_function.auth_cognito_test.function_name
}

output "lambda_auth_cognito_test_function_arn" {
  description = "Auth Cognito Test Lambda function ARN"
  value       = aws_lambda_function.auth_cognito_test.arn
}

# ============================================
# API Gateway Auth Endpoints
# ============================================

output "api_public_endpoint" {
  description = "API Gateway Public endpoint URL"
  value       = "${aws_apigatewayv2_api.hello_vpc_api.api_endpoint}/public"
}

output "api_protected_endpoint" {
  description = "API Gateway Protected endpoint URL"
  value       = "${aws_apigatewayv2_api.hello_vpc_api.api_endpoint}/protected"
}
