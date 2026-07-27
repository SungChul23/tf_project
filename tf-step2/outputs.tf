# terraform apply 실행 후, 터미널에 출력해줄 값들을 정의
# 예: 생성된 EC2의 IP를 바로 확인하고 싶을 때

# VPC, 서브넷 정보 출력
output "get_vpc_id" {
  value       = data.aws_vpc.default.id
  description = "서울리전의 기본 VPC의 id"
}

output "get_subnets_id" {
  value       = data.aws_subnets.default.ids
  description = "서울리전의 서브넷 ID"
}

# AMI 정보 출력
output "get_amazone_linux_id" {
  value       = data.aws_ami.get_amazon_linux.id
  description = "EC2 os 중에서 아마존 리눅스 계열 알아보기"
}

# EC2 관련 출력 (count = 2 라서 리스트로 나옴)
output "get_public_IP" {
  value       = aws_instance.de-ai-22-IaC-EC2[*].public_ip
  description = "EC2 2개의 퍼블릭 IP 목록"
}

output "get_EC2_ID" {
  value       = aws_instance.de-ai-22-IaC-EC2[*].id
  description = "EC2 2개의 인스턴스 ID 목록"
}


/*
# EIP 출력 (실제 접속에 쓸 고정 IP)
output "get_EIP" {
  value       = aws_eip.de-ai-22-IaC-EIP[*].public_ip
  description = "EIP 2개 목록"
}
*/