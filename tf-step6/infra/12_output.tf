##########################################
# EKS 설정 관련 변수 - 아웃풋
##########################################

output "region" {
  value       = var.region
  description = "AWS 리전"
}

output "cluster_name" {
  # 임시
  value       = local.cluster_name
  description = "EKS 클러스터명"
}

##########################################
# [네트워크] VPC, 서브넷(2개), AZ, CIDR  - 아웃풋
##########################################

