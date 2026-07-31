variable "region" {
  default = "us-east-1"
  description = "북부-버즈니아 리전"
  type = string
}

##########################################
# 테라폼에 사용될 변수 정의
##########################################

variable "enviroment" {
  default = "dev"
  description = "구동 환경"
  type = string
}

variable "instance_type" {
  default = "t3.micro"
  description = "web/was에 대한 인스턴스 유형"
  type = string
}

variable "web_desired_capacity" {
  default = "2"
  description = "WEB ASG 기본 인스턴스 수"
  type = number
}

variable "was_desired_capacity" {
  default = "2"
  description = "WAS ASG 기본 인스턴스 수"
  type = number
}

variable "db_instance_class" {
  default = "db.t3.micro"
  description = "rds 인스턴스"
  type = string
}

variable "db_name" {
  default = "app_db"
  description = "초기 생성 db 명"
  type = string
}

variable "db_username" {
  default = "root"
  description = "관리자명"
  type = string
}