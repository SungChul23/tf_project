# ============================================================
# WEB ASG (Auto Scaling Group)
# ============================================================

# WEB Auto Scaling Group — WEB 인스턴스 개수를 자동으로 유지/조절
# Public ALB → WEB Target Group으로 연결된 인스턴스들이 여기서 관리됨
resource "aws_autoscaling_group" "web" {
  name = "${local.project}-WEB-ASG"

  min_size         = 2                        # 최소 2대 (AZ 2곳 × 1대씩, 최소 HA 보장)
  desired_capacity = var.web_desired_capacity # 평상시 유지할 목표 대수
  max_size         = 4                        # 트래픽 급증 시 최대 확장 한도

  vpc_zone_identifier = [for subnet in aws_subnet.app : subnet.id] # App-Private 서브넷(AZ-A, AZ-C)에 분산 배치
  target_group_arns   = [aws_lb_target_group.web.arn]              # Public ALB의 WEB TG에 자동 등록

  health_check_type         = "ELB" # ALB 헬스체크 기준으로 판단 (EC2 상태만 보는 것보다 더 정확)
  health_check_grace_period = 180   # 인스턴스 기동 후 180초는 헬스체크 유예 (부팅/앱 초기화 시간 확보)

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest" # 런치 템플릿 최신 버전 자동 반영
  }

  # 배포 시 인스턴스를 한 번에 교체하지 않고 순차적으로 교체 (무중단 배포)
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50 # 교체 중에도 최소 50%는 항상 정상 상태 유지
    }
  }

  # 공통 태그(local.common_tag) + WEB 전용 태그(Name, Tier)를 병합해서 동적으로 적용
  dynamic "tag" {
    for_each = merge(local.common_tag, {
      Name = "${local.project}-WEB"
      Tier = "WEB"
    })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true # ASG가 생성하는 각 EC2 인스턴스에도 태그 자동 전파
    }
  }
}

# ============================================================
# WAS ASG (Auto Scaling Group)
# ============================================================

# WAS Auto Scaling Group — WAS 인스턴스 개수를 자동으로 유지/조절
# Internal ALB → WAS Target Group으로 연결된 인스턴스들이 여기서 관리됨
resource "aws_autoscaling_group" "was" {
  name = "${local.project}-WAS-ASG"

  min_size         = 2
  desired_capacity = var.was_desired_capacity
  max_size         = 4

  vpc_zone_identifier = [for subnet in aws_subnet.app : subnet.id]
  target_group_arns   = [aws_lb_target_group.was.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 240 # WAS는 WEB보다 기동/초기화가 오래 걸려서 유예 시간을 더 길게 설정

  launch_template {
    id      = aws_launch_template.was.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  dynamic "tag" {
    for_each = merge(local.common_tag, {
      Name = "${local.project}-WAS"
      Tier = "WAS"
    })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# ============================================================
# AUTO SCALING POLICIES (CPU 기준 Target Tracking)
# ============================================================

# WEB CPU 기반 오토스케일링 정책
# 평균 CPU 사용률이 50%를 유지하도록 ASG의 desired_capacity를 자동 증감
resource "aws_autoscaling_policy" "web_cpu" {
  name                   = "${local.project}-WEB-CPU-50"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "TargetTrackingScaling" # 목표 값을 기준으로 자동 추적하며 조절하는 방식

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization" # ASG 전체 인스턴스의 평균 CPU 기준
    }
    target_value = 50 # CPU 평균 50% 유지가 목표
  }
}

# WAS CPU 기반 오토스케일링 정책 (WEB과 동일한 방식, 대상 ASG만 다름)
resource "aws_autoscaling_policy" "was_cpu" {
  name                   = "${local.project}-WAS-CPU-50"
  autoscaling_group_name = aws_autoscaling_group.was.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50
  }
}