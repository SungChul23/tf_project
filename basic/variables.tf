# 재사용 가능한 변수들을 "선언"만 하는 파일
# 실제 값은 여기 안 넣고, terraform.tfvars 또는 실행 시 입력받음

variable "region" {
    default = "ap-northeast-2"
}
variable "instance_type" {
    default = "t3.micro"
}
variable "key_name" {
    default = "de-ai-22-key"
}

# 리전, 인스턴스 타입, pem 파일 변수로 지정 -