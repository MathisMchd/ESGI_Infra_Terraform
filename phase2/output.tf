output "security_group_id" {
  value       = aws_security_group.rds_sg_phase_2.id
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