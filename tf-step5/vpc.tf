# VPC

resource "aws_vpc" "main" {
  # CIDR 규칙 지정 65536개 IP를 구성할수 있다. 10.0.0.0/16
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${local.project}-VPC"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {

  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.project}-IGW"
  }
}

# Public Subnets (Public ALB, NAT GW)
resource "aws_subnet" "public" {

  for_each = local.public_subnets

  vpc_id = aws_vpc.main.id

  cidr_block = each.value ## a,c

  availability_zone = local.azs[each.key]

  map_public_ip_on_launch = true ## 퍼블릭 IP 할당할것인가 ?

  # 태그 지정
  tags = {
    Name = "${local.project}-public-subnet-${upper(each.key)}"
    # 커스텀 테그
    Tier = "public"
  }
}


# Private App Subnets (WEB, WAS, Internal ALB)
resource "aws_subnet" "app" {

  for_each = local.app_subnets

  vpc_id = aws_vpc.main.id

  cidr_block = each.value ## a,c

  availability_zone = local.azs[each.key]

  map_public_ip_on_launch = false ## 퍼블릭 IP 할당할것인가 ?

  # 태그 지정
  tags = {
    Name = "${local.project}-app-private-${upper(each.key)}"
    # 커스텀 테그
    Tier = "app"
  }
}

# Private Db Subnets - RDS
resource "aws_subnet" "db" {

  for_each = local.db_subnets

  vpc_id = aws_vpc.main.id

  cidr_block = each.value ## a,c

  availability_zone = local.azs[each.key]

  map_public_ip_on_launch = false ## 퍼블릭 IP 할당할것인가 ?

  # 태그 지정
  tags = {
    Name = "${local.project}-db-private-${upper(each.key)}"
    # 커스텀 테그
    Tier = "db"
  }
}

# Route Tables & Associations
# 라우팅 테이블 생성 
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {

    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.project}-PUBLIC-RT"
  }

}

# 라우팅 테이블을 서브넷에 바인딩
resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Nate Gateway - eip
resource "aws_eip" "nat" {
  for_each = local.azs
  domain   = "vpc"

  tags = {
    Name = "${local.project}-nat-eip-${each.key}"
  }
}

# Private App Route Table/association  - Web, Was
resource "aws_nat_gateway" "main" {
  for_each = local.azs

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = {
    Name = "${local.project}-NAT-${upper(each.key)}"
  }

  # IGW가 NAT보다 먼저 생성/연결되어 있어야 한다
  depends_on = [aws_internet_gateway.main]
}

# 프라이빗 라우팅 테이블 생성 + NAT G/W 연결까지 마무리
resource "aws_route_table" "app" {
  for_each = local.azs
  vpc_id   = aws_vpc.main.id


  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.main[each.key].id
  }


  tags = {
    Name = "${local.project}-APP-RT-${upper(each.key)}"
  }
}

# App Route Table을 App 서브넷에 연결(Association)
resource "aws_route_table_association" "app" {
  for_each = aws_subnet.app

  subnet_id      = each.value.id
  route_table_id = aws_route_table.app[each.key].id

}

# Private Db Route Table/association  - RDS
resource "aws_route_table" "db" {
  vpc_id = aws_vpc.main.id
  # route 블록 없음 -VPC 안에서 서로 통신하는 것
  
  tags = {
    Name = "${local.project}-DB-RT" # 
  }
}

resource "aws_route_table_association" "db" {
  for_each = aws_subnet.db

  subnet_id      = each.value.id
  route_table_id = aws_route_table.db.id
}

