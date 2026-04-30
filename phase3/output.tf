output "load_balancer_dns_name" {
  description = "DNS name of the application load balancer"
  value       = aws_lb.app.dns_name
}

output "application_url" {
  description = "Public URL of the application"
  value       = "http://${aws_lb.app.dns_name}"
}

output "rds_hostname" {
  description = "RDS instance hostname"
  value       = aws_db_instance.mysql_instance.address
  sensitive   = true
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.mysql_instance.port
  sensitive   = true
}

output "rds_username" {
  description = "RDS instance root username"
  value       = aws_db_instance.mysql_instance.username
  sensitive   = true
}