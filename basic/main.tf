# 실제로 생성할 AWS 리소스들을 정의하는 핵심 파일
# EC2, 보안그룹, VPC 등 "뭘 만들지"가 여기 다 들어감

# 1. 현재 리전의 VPC 서비스중 default 정보 조회 (data)
# - 현재 리전의 VPC 서비스 중 default 정보 조회 하라 -> data.aws_vpc.default.id 참조

data "aws_vpc" "default" {
    default = true
  
}

# 2. 기본 VPC의 서비스 정보 조회 하라 (data)
# - n개의 서브넷이 존재하므로 이름 values에 담아라

data "aws_subnets" "default" {
    filter {
      name = "vpc-id"
      values = [data.aws_vpc.default.id]
    }
    
}