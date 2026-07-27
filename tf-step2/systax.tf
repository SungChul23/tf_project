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