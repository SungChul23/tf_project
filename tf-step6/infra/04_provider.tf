# 리전시를 위한 AWS Provider 설정

provider "aws" {
  region = var.region  
  default_tags {
    tags = local.common_tags
  }
}