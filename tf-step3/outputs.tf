output "custom_vpc_id" {
  value       = aws_vpc.de-ai-22-company.id
  description = "생성된 Custom VPC의 ID"
}

output "custom_subnet_id" {
  value       = aws_subnet.public.id
  description = "생성된 Custom Public Subnet의 ID"
}

output "ec2_id" {
  value       = aws_instance.de-ai-22-IaC-EC2.id
  description = "생성된 EC2 인스턴스 ID"
}

# EIP로 할당된 고정 퍼블릭 IP 출력
output "ec2_eip_public_ip" {
  value       = aws_eip.de-ai-22-IaC-EIP.public_ip
  description = "EC2에 할당된 탄력적 IP (EIP)"
}