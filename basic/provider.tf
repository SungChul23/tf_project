# 어떤 클라우드 사업자를 쓸지, 리전은 어디인지 정의하는 파일
# 이 프로젝트 전체의 "출발점" 역할

terraform {
  required_version = ">=1.10"
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~>6.0"
    }

  }
}
provider "aws" {
  region = var.region
}
#공급자 설명, 버전
#AWS provider 버전 설명, 서울리전 지정
#변수가 없으므로 한시적 하드코딩 allow