# 특정 기업/개인/단체등 전용 VPC 생성 선언

resource "aws_vpc" "de-ai-22-company" {
  # CIDR 규칙 지정 65536개 IP를 구성할수 있다. 10.0.0.0/16
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    Name = "de-ai-22-company"
  }
}

# 서브넷
resource "aws_subnet" "public" {
  # 암묵적 의존성 -> 서브넷 구성을 위해서는 반드시 VPC가 있어야함 , 즉 create First
  vpc_id = aws_vpc.de-ai-22-company.id

  # 앞 3자리 고정 -> 256개 가용 가능
  cidr_block = "10.0.1.0/24"

  availability_zone = "ap-northeast-2a"

  map_public_ip_on_launch = true

  # 태그 지정
  tags = {
    Name = "de-ai-22-public-subnet"
  }
}