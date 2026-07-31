# 사용자 → Public ALB(80) → WEB → Internal ALB(8000) → WAS.

# 1. 요청이 ALB(건물)의 80번 포트로 도착
# 2. Listener(안내 데스크)가 "80번이니까 WEB Target Group으로 보내자" 결정
# 3. Target Group(명단)에서 "지금 살아있는(healthy) 인스턴스" 중 하나를 골라서 실제 전달
# 4. 그 인스턴스(WEB EC2)가 요청 처리

# ============================================================
# PUBLIC ALB (사용자 → WEB)
# ============================================================

# Public ALB — 인터넷에서 유일하게 직접 접근 가능한 진입점
# Public 서브넷(2개 AZ)에 걸쳐 배치되어 트래픽을 분산 + HA 확보
resource "aws_lb" "public" {
  name               = "${local.project}-public-alb"
  internal           = false                                       # false = 퍼블릭(인터넷 대면), true면 내부 전용
  load_balancer_type = "application"                                # L7 로드밸런서 (HTTP/HTTPS 라우팅)
  security_groups    = [aws_security_group.public_alb.id]           # 0.0.0.0/0 인바운드를 허용하는 유일한 SG
  subnets            = [for subnet in aws_subnet.public : subnet.id] # AZ-A, AZ-C Public 서브넷 모두 등록

  tags = {
    Name = "${local.project}-PUBLIC-ALB"
  }
}

# WEB Target Group — Public ALB가 트래픽을 전달할 대상(WEB ASG 인스턴스들)을 정의
# ASG 쪽에서 target_group_arns로 이 Target Group을 참조해 인스턴스를 자동 등록/해제함
resource "aws_lb_target_group" "web" {
  name        = "${local.project}-web-tg"
  port        = 80             # WEB 인스턴스가 실제로 리스닝하는 포트
  protocol    = "HTTP"
  target_type = "instance"      # 대상이 EC2 인스턴스 ID 기반 (ASG와 연동되는 표준 방식)
  vpc_id      = aws_vpc.main.id

  # 헬스 체크 — 비정상 인스턴스를 자동으로 트래픽 라우팅에서 제외
  health_check {
    enabled             = true
    path                = "/health"   # 헬스 체크용 엔드포인트 (WEB 앱에 구현되어 있어야 함)
    protocol            = "HTTP"
    matcher             = "200"        # 200 응답만 정상으로 판단
    interval            = 30           # 30초마다 체크
    timeout             = 5
    healthy_threshold   = 2            # 2번 연속 성공 → 정상 판정
    unhealthy_threshold = 2            # 2번 연속 실패 → 비정상 판정, 트래픽 제외
  }

  tags = {
    Name = "${local.project}-WEB-TG"
  }
}

# Public ALB Listener — 80번 포트로 들어온 요청을 WEB Target Group으로 전달
# 실제 라우팅 규칙(어느 포트로 받아서 어디로 보낼지)을 정의하는 지점
resource "aws_lb_listener" "public_http" {
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"                    # 별도 규칙 없으면 무조건 WEB TG로 전달
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# ============================================================
# INTERNAL ALB (WEB → WAS)
# ============================================================

# Internal ALB — WEB에서 WAS로 가는 트래픽만 처리하는 내부 전용 로드밸런서
# Private App 서브넷에 위치, 외부(인터넷)에서는 접근 자체가 불가능
resource "aws_lb" "internal" {
  name               = "${local.project}-internal-alb"
  internal           = true                                      # 내부 전용 — 인터넷에 노출 안 됨
  load_balancer_type = "application"
  security_groups    = [aws_security_group.internal_alb.id]       # WEB SG로부터의 트래픽만 허용
  subnets            = [for subnet in aws_subnet.app : subnet.id] # Private App 서브넷(AZ-A, AZ-C)에 배치

  tags = {
    Name = "${local.project}-INTERNAL-ALB"
  }
}

# WAS Target Group — Internal ALB가 트래픽을 전달할 대상(WAS ASG 인스턴스들)
resource "aws_lb_target_group" "was" {
  name        = "${local.project}-was-tg"
  port        = 8000             # WAS 인스턴스가 리스닝하는 포트
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${local.project}-WAS-TG"
  }
}

# Internal ALB Listener — 8000번 포트로 들어온 WEB→WAS 요청을 WAS Target Group으로 전달
resource "aws_lb_listener" "internal_http" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 8000
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.was.arn
  }
}