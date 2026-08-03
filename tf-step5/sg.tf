# ============================================================
# PUBLIC ALB SECURITY GROUP
# ============================================================

# Public ALB SG — 인터넷 전체(0.0.0.0/0)에서 오는 트래픽을 허용하는 "유일한" 지점
# 이 뒤의 모든 계층(WEB, WAS, RDS)은 인터넷 직접 노출이 전혀 없음
resource "aws_security_group" "public_alb" {
  name        = "${local.project}-PUBLIC-ALB-SG"
  description = "Allow internet HTTP traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # 모든 프로토콜/포트 허용 (ALB → WEB 등 뒷단으로 전달)
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.project}-PUBLIC-ALB-SG" }
}

# ============================================================
# WEB SECURITY GROUP
# ============================================================

# WEB SG — Public ALB로부터 오는 트래픽만 허용, 인터넷 직접 접근 불가
# 소스를 CIDR이 아닌 SG ID로 지정해서 "Public ALB를 통한 트래픽만" 정확히 필터링
resource "aws_security_group" "web" {
  name        = "${local.project}-WEB-SG"
  description = "Allow HTTP only from public ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from public ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.public_alb.id] # Public ALB SG를 단 리소스만 허용
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # WEB → Internal ALB, 그리고 NAT 경유 외부 통신(업데이트 등)
  }

  tags = { Name = "${local.project}-WEB-SG" }
}

# ============================================================
# INTERNAL ALB SECURITY GROUP
# ============================================================

# Internal ALB SG — WEB 계층으로부터 오는 트래픽만 허용
# Internal ALB 자체는 internal=true라서 애초에 인터넷 노출 자체가 불가능, SG로 한 번 더 계층 검증
resource "aws_security_group" "internal_alb" {
  name        = "${local.project}-INTERNAL-ALB-SG"
  description = "Allow WAS traffic only from WEB tier"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "WAS request from WEB"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id] # WEB SG를 단 리소스만 허용
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Internal ALB → WAS로 전달
  }

  tags = { Name = "${local.project}-INTERNAL-ALB-SG" }
}

# ============================================================
# WAS SECURITY GROUP
# ============================================================

# WAS SG — Internal ALB로부터 오는 트래픽만 허용
resource "aws_security_group" "was" {
  name        = "${local.project}-WAS-SG"
  description = "Allow application traffic only from internal ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Application traffic from internal ALB"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.internal_alb.id] # Internal ALB SG를 단 리소스만 허용
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # WAS → RDS, 그리고 NAT 경유 외부 통신(패키지 설치 등)
  }

  tags = { Name = "${local.project}-WAS-SG" }
}

# ============================================================
# RDS SECURITY GROUP
# ============================================================

# RDS SG — WAS 계층으로부터 오는 MySQL(3306) 트래픽만 허용
# 가장 안쪽 계층이라 인바운드가 WAS SG 하나로만 극도로 좁혀져 있음
resource "aws_security_group" "rds" {
  name        = "${local.project}-RDS-SG"
  description = "Allow MySQL only from WAS tier"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from WAS"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.was.id] # WAS SG를 단 리소스만 허용
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.project}-RDS-SG" }
}