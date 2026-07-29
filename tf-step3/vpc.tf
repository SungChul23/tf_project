# 특정 기업/개인/단체등 전용 VPC 생성 선언

# VPC 생성
resource "aws_vpc" "de-ai-22-company" {
  # CIDR 규칙 지정 65536개 IP를 구성할수 있다. 10.0.0.0/16
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    Name = "de-ai-22-company"
  }
}

# 서브넷 생성
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

# 인터넷 GW 생성
resource "aws_internet_gateway" "company" {

  vpc_id = aws_vpc.de-ai-22-company.id

  tags = {
    Name = "de-ai-22-company-igw"
  }
}

# 라우팅 테이블 생성
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.de-ai-22-company.id
  route {

    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.company.id
  }

  tags = {
    Name = "de-ai-22-company-public-rt"
  }

}

# 가장 중요 : 라우팅 테이블을 서브넷에 바인딩
resource "aws_route_table_association" "public" {
    subnet_id = aws_subnet.public.id
    route_table_id = aws_route_table.public.id
}


