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
