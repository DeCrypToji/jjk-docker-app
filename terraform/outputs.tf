output "alb_dns_name" {
  description = "ALB DNS name — use this to access the app"
  value       = aws_lb.jjk_alb.dns_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.jjk_cluster.name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.jjk_service.name
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.jjk_sg.id
}

# output "acm_certificate_arn" {
#   description = "ACM certificate ARN"
#   value       = aws_acm_certificate.jjk_cert.arn
# }