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