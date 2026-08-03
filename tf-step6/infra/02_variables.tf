##########################################
# 테라폼에 사용될 공통 변수 정의
##########################################

variable "region" {
  default     = "us-east-1"
  description = "북부-버즈니아 리전"
  type        = string
}

variable "project_name" {
  default     = "de-ai-22-eks-auto"
  description = "사용할 프로젝트 명"
  type        = string
}

variable "environment" {
  default     = "dev"
  description = "구동 환경"
  type        = string
}

##########################################
# [네트워크] VPC, 서브넷(2개), AZ, CIDR 
##########################################

variable "vpc_cidr" {
  default     = "10.0.0.0/16"
  description = "VPC CIDR 블록"
  type        = string
}

variable "public_subnet_cidrs" {
  default     = ["10.0.1.0/24","10.0.2.0/24"]
  description = "퍼블릭 서브넷 CIDR 블록"
  type        = list(string)
}

variable "app_subnet_cidrs" {
  default     = ["10.0.11.0/24","10.0.12.0/24"]
  description = "EKS Auto Mode Node/Pod 용 프라이빗 서브넷 CIDR 블록"
  type        = list(string)
}

variable "db_subnet_cidrs" {
  default     = ["10.0.21.0/24","10.0.22.0/24"]
  description = "RDS 용 프라이빗 서브넷 CIDR 블록"
  type        = list(string)
}

variable "availability_zones" {
  default     = ["us-east-1a", "us-east-1c"]
  description = "Mulit-AZ를 위한 가용 영역 리스트"
  type        = list(string)
  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "최소 2개의 가용 영역을 지정해야 합니다."
  }
}

##########################################
# EKS 설정 관련 변수
##########################################

variable "kubernetes_version" {
  default     = "1.35"
  description = "EKS 클러스터에 사용할 쿠버네티스 버전"
  type        = string
}

variable "cluster_endpoint_public_access" {
  default     = ["0.0.0.0/0"]
  description = "EKS public endpoint 접근 허용 여부"
  type        = list(string)
}
variable "additional_admin_role_arns" {
  default     = []
  description = "EKS 클러스터에 대한 추가 관리자 역할 ARN"
  type        = set(string)
}

##########################################
# RDS 설정
##########################################

variable "db_instance_class" {
  default     = "db.t3.micro"
  description = "RDS 인스턴스 클래스"
  type        = string
}

variable "db_allocated_storage" {
  default     = 20
  description = "RDS 인스턴스에 할당할 저장소 크기 (GB)"
  type        = number
}

variable "db_name" {
  default     = "app_db"
  description = "초기 생성 db 명"
  type        = string
}

variable "db_username" {
  default     = "admin"
  description = "관리자명"
  type        = string
}