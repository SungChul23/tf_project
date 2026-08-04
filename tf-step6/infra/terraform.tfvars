aws_region   = "us-east-1"
project_name = "de-ai-22-eks-auto"
environment  = "dev"

kubernetes_version = "1.35"

# 수업 실습 편의상 세팅
# 운영 환경에서는 반드시 본인/회사 공인 IP만 허용
cluster_endpoint_public_access = ["0.0.0.0/0"]
# 추가 관리자 Role이 필요한 경우만 입력
additional_admin_role_arns = []

# 비용을 더 낮추려면 Single-AZ로 변경할 수 있지만 현재는 v2와 동일한 Multi-AZ 효과를 유지
db_instance_class    = "db.t3.micro"
db_allocated_storage = 20