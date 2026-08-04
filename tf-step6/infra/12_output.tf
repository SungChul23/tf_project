# 만들어진 정보를 기반 => 리소스명, id, arn등 동적으로 만들어진 값 
# => 쿠버네티스 mainfest(구성 정보) 등등 동적 설정하기 위해 필요한 값은 출력 


# ─────────────────────────────────────────────
# EKS 정보
# ─────────────────────────────────────────────
output "aws_region" {
  value = var.aws_region
}

output "cluster_name" {
  value = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "cluster_security_group_id" {
  value = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "auto_mode_node_role_arn" {
  value = aws_iam_role.eks_auto_node.arn
}

# kubectl 연결 설정에 사용할 명령
# 로컬 PC -> kubectl CLI 이용 -> 쿠버네티스에 접속 -> API Server 통신 -> 관리/지시 .. 수행
# 리전, 클러스터 정보 필요 -> 구성 업데이트 명령어
output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}

# ─────────────────────────────────────────────
# VPC/Subnet 정보
# ─────────────────────────────────────────────
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = values(aws_subnet.public)[*].id
}

output "app_subnet_ids" {
  value = values(aws_subnet.app)[*].id
}

output "db_subnet_ids" {
  value = values(aws_subnet.db)[*].id
}

# ─────────────────────────────────────────────
# ECR 정보
# ─────────────────────────────────────────────
output "web_ecr_repository_url" {
  value = aws_ecr_repository.web.repository_url
}

output "was_ecr_repository_url" {
  value = aws_ecr_repository.was.repository_url
}

# ─────────────────────────────────────────────
# RDS 정보
# ─────────────────────────────────────────────
output "rds_endpoint" {
  value = aws_db_instance.mysql.address
}

output "rds_port" {
  value = aws_db_instance.mysql.port
}

output "rds_db_name" {
  value = var.db_name
}

# 비밀번호 자체가 아니라 Secrets Manager의 ARN이며 출력 시 숨김 처리한다.
output "rds_master_secret_arn" {
  value     = aws_db_instance.mysql.master_user_secret[0].secret_arn
  sensitive = true
}