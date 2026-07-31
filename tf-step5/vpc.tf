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


# Public Route Table/association 

# Nate Gateway - eip

# Private App Route Table/association  - Web, Was

# Private Db Route Table/association  - RDS
