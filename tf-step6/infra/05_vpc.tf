# ============================================================
# EKS / RDS가 들어갈 VPC 네트워크 구성
# 구조: Public 2개 (ALB, NAT) / App Private 2개 (EKS 노드) / DB Private 2개 (RDS)
# ============================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.cluster_name}-vpc"
  }
}

# 인터넷 게이트웨이 — VPC와 인터넷을 연결하는 유일한 출입구
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.cluster_name}-igw"
  }
}

# ------------------------------------------------------------
# 서브넷 3종
# ------------------------------------------------------------

# [Public] ALB, NAT Gateway가 위치하는 서브넷
# "kubernetes.io/role/elb" 태그: AWS Load Balancer Controller가 이 태그를 보고
# "외부 공개용 ALB를 놓을 서브넷"으로 자동 인식함
resource "aws_subnet" "public" {
  for_each = local.public_subnet

  vpc_id                  = aws_vpc.main.id
  cidr_block               = each.value.cidr
  availability_zone        = each.value.az
  map_public_ip_on_launch  = true # 이 서브넷에서 뜨는 리소스는 퍼블릭 IP 자동 할당

  tags = {
    Name                     = "${local.cluster_name}-public-subnet-${each.key}"
    "kubernetes.io/role/elb" = 1
  }
}

# [Private-App] EKS 노드/Pod가 위치하는 서브넷 (WEB, WAS 등)
# "kubernetes.io/role/internal-elb" 태그: 내부용(비공개) 로드밸런서를 놓을 서브넷으로 인식
resource "aws_subnet" "app" {
  for_each = local.app_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block               = each.value.cidr
  availability_zone        = each.value.az
  map_public_ip_on_launch  = false # 퍼블릭 IP 없음 → 외부에서 직접 접근 불가

  tags = {
    Name                              = "${local.cluster_name}-app-private-${each.key}"
    "kubernetes.io/role/internal-elb" = 1
  }
}

# [Private-DB] RDS가 위치하는 서브넷
# 로드밸런서와 무관하므로 kubernetes.io 태그 자체가 필요 없음
resource "aws_subnet" "db" {
  for_each = local.db_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block               = each.value.cidr
  availability_zone        = each.value.az
  map_public_ip_on_launch  = false

  tags = {
    Name = "${local.cluster_name}-db-private-${each.key}"
  }
}

# ============================================================
# NAT Gateway — Private 서브넷이 "나가는" 인터넷 트래픽을 처리
# (외부 → 내부로 들어오는 건 막고, 내부 → 외부로 나가는 것만 허용하는 편도 문)
# ============================================================

# NAT Gateway 전용 고정 IP. AZ(가용영역)마다 하나씩, 총 2개
resource "aws_eip" "nat" {
  for_each = aws_subnet.public
  domain   = "vpc"

  tags = {
    Name = "${local.cluster_name}-nat-eip-${each.key}"
  }

  depends_on = [aws_internet_gateway.main] # IGW가 먼저 있어야 EIP를 VPC에 붙일 수 있음
}

# NAT Gateway 본체. Public 서브넷 위에 놓이지만, 실제로 서비스하는 대상은 Private 서브넷
resource "aws_nat_gateway" "main" {
  for_each = aws_subnet.public

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value.id

  tags = {
    Name = "${local.cluster_name}-nat-${each.key}"
  }

  depends_on = [aws_internet_gateway.main] # IGW가 먼저 VPC에 연결되어 있어야 정상 동작
}

# ============================================================
# 라우트 테이블 — 서브넷별로 "나갈 때 어느 문을 쓸지" 정하는 이정표
# ============================================================

# --- [Public] IGW로 직접 나감 ---
# 라우트 테이블 1개를 만들어서, Public 서브넷 2개가 공유해서 사용
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.cluster_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# --- [Private-App] 같은 AZ의 NAT Gateway로 나감 ---
# AZ마다 라우트 테이블을 따로 만드는 이유: 장애 격리(HA)
# 한쪽 AZ의 NAT Gateway가 죽어도, 다른 AZ의 App 서브넷은 영향받지 않음
resource "aws_route_table" "app" {
  for_each = aws_subnet.app
  vpc_id   = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[each.key].id
  }

  tags = {
    Name = "${local.cluster_name}-app-rt-${each.key}"
  }
}

resource "aws_route_table_association" "app" {
  for_each = aws_subnet.app

  subnet_id      = each.value.id
  route_table_id = aws_route_table.app[each.key].id
}

# --- [Private-DB] 외부로 나가는 라우트 자체가 없음 ---
# route 블록이 비어있음 = VPC 내부(local) 통신만 가능, 인터넷 완전 격리
# (RDS는 앱 서버의 연결만 받으면 되고, 스스로 외부에 나갈 일이 없음)
resource "aws_route_table" "db" {
  for_each = aws_subnet.db
  vpc_id   = aws_vpc.main.id

  tags = {
    Name = "${local.cluster_name}-db-rt-${each.key}"
  }
}

resource "aws_route_table_association" "db" {
  for_each = aws_subnet.db

  subnet_id      = each.value.id
  route_table_id = aws_route_table.db[each.key].id
}