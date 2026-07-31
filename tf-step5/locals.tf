##########################################
# 전체 구성상 반복적으로 배치되는 변수값들 구성
##########################################

locals {
  # 프로젝트명 
    project = "de-ai-22-IaC-3tier-v1"

  # 리소스에 적용된 공용 테그
    common_tag ={
        Project = local.project
        Environment = var.environment
        ManagedBy   = "terraform"
    }

    # 버지니아 북부 리전 2개 AZ (a, b 또는 c 등선택 가능)
    azs ={
        a = "us-east-1a"
        c = "us-east-1c"
    }

  #ALB 
  public_subnets = {
    a = "10.0.1.0/24"
    c = "10.0.2.0/24"
  }
  # web/was - asg
  app_subnets ={
    a = "10.0.11.0/24"
    c = "10.0.12.0/24"
  }
  # RDS
  db_subnets ={
    a = "10.0.21.0/24"
    c = "10.0.22.0/24"
  }


  #WEB/WAS ASG

  # RDS
}