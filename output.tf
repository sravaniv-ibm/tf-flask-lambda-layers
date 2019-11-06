output "deployment_invoke_url" {
  description = "Deployment invoke url"
  value       = "${aws_api_gateway_deployment.deployment.invoke_url}"
}

output "http_method" {
  value = "${aws_api_gateway_method.method.http_method}"
}