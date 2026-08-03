output "public_alb_url" {
  description = "브라우저 접속 주소"
  value       = "http://${aws_lb.public.dns_name}"
}

output "public_alb_dns" {
  value = aws_lb.public.dns_name
}

output "internal_alb_dns" {
  value = aws_lb.internal.dns_name
}

output "rds_endpoint" {
  value = aws_db_instance.mysql.endpoint
}

output "rds_master_secret_arn" {
  description = "AWS Secrets Manager에서 관리되는 RDS 관리자 비밀번호 Secret ARN"
  value       = try(aws_db_instance.mysql.master_user_secret[0].secret_arn, null)
}

output "web_asg_name" {
  value = aws_autoscaling_group.web.name
}

output "was_asg_name" {
  value = aws_autoscaling_group.was.name
}