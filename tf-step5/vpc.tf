# ============================================================
# VPC
# ============================================================
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16" # 65,536개 IP 대역
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.project}-VPC"
  }
}

# ============================================================
# INTERNET GATEWAY (VPC 전체의 인터넷 관문, VPC당 1개)
# ============================================================
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.project}-IGW"
  }
}

# ============================================================
# SUBNETS
# ============================================================

# Public Subnet — Public ALB, NAT Gateway 위치
resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = local.azs[each.key]
  map_public_ip_on_launch = true # 퍼블릭 IP 자동 할당

  tags = {
    Name = "${local.project}-PUBLIC-SUBNET-${upper(each.key)}"
    Tier = "PUBLIC"
  }
}

# Private App Subnet — WEB, WAS, Internal ALB 위치
resource "aws_subnet" "app" {
  for_each = local.app_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = local.azs[each.key]
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.project}-APP-PRIVATE-${upper(each.key)}"
    Tier = "APP"
  }
}

# Private DB Subnet — RDS 위치
resource "aws_subnet" "db" {
  for_each = local.db_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = local.azs[each.key]
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.project}-DB-PRIVATE-${upper(each.key)}"
    Tier = "DB"
  }
}

# ============================================================
# NAT GATEWAY (Private 서브넷의 아웃바운드 트래픽 중계)
# ============================================================

# EIP — NAT Gateway 전용 고정 퍼블릭 IP, AZ별로 1개씩
resource "aws_eip" "nat" {
  for_each = local.azs
  domain   = "vpc"

  tags = {
    Name = "${local.project}-NAT-EIP-${upper(each.key)}"
  }
}

# NAT Gateway — Public 서브넷에 위치, Private 서브넷의 아웃바운드 트래픽 처리
resource "aws_nat_gateway" "main" {
  for_each = local.azs

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = {
    Name = "${local.project}-NAT-${upper(each.key)}"
  }

  # IGW가 먼저 VPC에 연결되어 있어야 NAT Gateway가 정상 동작
  depends_on = [aws_internet_gateway.main]
}

# ============================================================
# ROUTE TABLES & ASSOCIATIONS
# ============================================================

# --- PUBLIC ---
# Public Route Table — 외부 트래픽은 IGW로
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

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# --- PRIVATE APP (WEB, WAS) ---
# App Route Table — 외부 트래픽은 같은 AZ의 NAT Gateway로 (AZ별 분리 = 장애 격리, HA 목적)
resource "aws_route_table" "app" {
  for_each = local.azs
  vpc_id   = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[each.key].id
  }

  tags = {
    Name = "${local.project}-APP-RT-${upper(each.key)}"
  }
}

resource "aws_route_table_association" "app" {
  for_each = aws_subnet.app

  subnet_id      = each.value.id
  route_table_id = aws_route_table.app[each.key].id
}

# --- PRIVATE DB (RDS) ---
# DB Route Table — 외부 아웃바운드 라우팅 없음 (VPC 내부 local 통신만 허용, 보안 격리 목적)
resource "aws_route_table" "db" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.project}-DB-RT"
  }
}

resource "aws_route_table_association" "db" {
  for_each = aws_subnet.db

  subnet_id      = each.value.id
  route_table_id = aws_route_table.db.id
}