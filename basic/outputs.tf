# terraform apply 실행 후, 터미널에 출력해줄 값들을 정의
# 예: 생성된 EC2의 IP를 바로 확인하고 싶을 때

# 임시코드 : vpc, 서브넷 출력

output "get_vpc_id" {
    value = data.aws_vpc.default.id
    description = "서울리전의 기본 VPC의 id"
}

output "get_subnets_id" {
    value = data.aws_subnets.default.ids
    description = "서울리전의 서브넷 ID"
}


# 출력결과 확인 (init -> plan -> apply -> destory)