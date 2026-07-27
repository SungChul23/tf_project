# 1. 변수
# 변수 선언 및 값 세팅

variable "name" {
  # 문자열 타입
  default = "Sungchul_Kim"
}

variable "age" {
  # 수치형 타입
  default = 26
}

variable "is_male" {
  # 불린 타입
  default = true
}

variable "skills" {
  # 리스트 타입
  default = ["java", "python"]
}

variable "stations" {
  # map 타입
  default = {
    DO = "경기도"
    SI = "화성시"
  }
}

# 출력
output "name" {
  value = var.name
}
output "age" {
  value = var.age
}
output "is_male" {
  value = var.is_male
}
output "skills" {
  value = var.skills
}
output "station" {
  value = var.stations
}


##########################################
# tfvars 테스트
##########################################

variable "enviroment" {
  type        = string
  default     = "dev"
  description = "배포환경 (dev -> stage -> prod)"
}

variable "instance_count" {
  type        = number
  default     = 1
  description = "생성할 EC2 갯수"

}

output "enviroment" {
  value = var.enviroment
}

output "instance_count" {
  value = var.instance_count
}

# locals
locals {
  project = "테라폼"
  env = "pod"
  name = "${local.project}-${local.env}"

}

output "local_value" {
  value = local.name
}


# 함수 (다양한 함수 지원)
output "upper_case" {
  value = upper(var.name)
}


# for_each
# 서비스별 인스턴스 유형 정의 리소스 구성 가정
# web : t3.micro, was:t3.small, db:t3.medium
locals {
  servers = {
    web = "t3.micro"
    was = "t3.small"
    db  = "t3.medium"
  }
}
output "for_each_value" {
  value = local.servers
}

# resource "temp_spec" "server" {
#   # 반복적으로 구성될 데이터 세팅 -> 내부적으로 반복
#   for_each = local.servers
  
#   # 내부에서 자동처리 예시
#   input = {
#     name = each.key
#     type = each.value
#   }
# }