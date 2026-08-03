# 이 프로젝트 전체의 "출발점" 역할
# terraform 을 실행할 때, 어떤 버전의 terraform 을 쓸지 정의

terraform {
  required_version = ">=1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.0"
    }

  }
}
