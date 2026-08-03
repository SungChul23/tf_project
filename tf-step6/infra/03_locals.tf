# 전역으로 사용할 local 변수를 정의하는 파일

locals {
    
  # 클러스터명 -> 프로젝트명-환경명
  cluster_name = "${var.project_name}-${var.environment}"


  # Multi-AZ를 위한 가용 영역 리스트
  az_keys = ["a", "c"]

    public_subnet_cidrs = {
        for index,key in local.az_keys : key => {
            az   = var.availability_zones[index]
            cidr = var.public_subnet_cidrs[index]
        }
    }
    
    # 위에서 나오는 최종 결과
    # public_subnet_cidrs = {
    #     a = {
    #         az = "us-east-1a"
    #         cidr = "10.0.1.0/24"
    #     }
    #     c = {
    #         az = "us-east-1c"
    #         cidr = "10.0.2.0/24"
    #     }
    # }

  public_subnets = {
    a = "10.0.1.0/24"
    c = "10.0.2.0/24"
  }

  app_subnets = {
    a = "10.0.11.0/24"
    c = "10.0.12.0/24"
  }

  db_subnets = {
    a = "10.0.21.0/24"
    c = "10.0.22.0/24"
  }



    common_tag = {
    Project     = local.cluster_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}