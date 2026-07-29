############################################
# Security Group Rules (반복관련)
############################################
locals {
  security_group = {
    web = {
      description = "WEB_tier_SG"
      ingress = [
        { port = 22,  cidr = ["0.0.0.0/0"], description = "SSH" },
        { port = 80,  cidr = ["0.0.0.0/0"], description = "HTTP" },
        { port = 443, cidr = ["0.0.0.0/0"], description = "HTTPS" },
      ]
      egress = [
        { port = 0, cidr = ["0.0.0.0/0"], protocol = "-1", description = "All outbound" }
      ]
    }

    was = {
      description = "WAS_tier_SG"
      ingress = [
        { port = 22, cidr = ["10.0.0.0/16"], description = "SSH from VPC (temp)" },
      ]
      egress = [
        { port = 0, cidr = ["0.0.0.0/0"], protocol = "-1", description = "All outbound" }
      ]
    }

    db = {
      description = "DB_tier_SG"
      ingress = [
        { port = 22, cidr = ["10.0.0.0/16"], description = "SSH from VPC (temp)" },
      ]
      egress = [
        { port = 0, cidr = ["0.0.0.0/0"], protocol = "-1", description = "All outbound" }
      ]
    }
  }
}

############################################
# Security Groups 생성 (cidr 기반 규칙만, source_sg 참조 없음)
############################################
resource "aws_security_group" "sg" {
  for_each = local.security_group

  name_prefix = "DE-AI-22-${each.key}-sg-"
  description = each.value.description
    vpc_id = aws_vpc.de-ai-22-company.id

  dynamic "ingress" {
    for_each = each.value.ingress
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = "tcp"
      cidr_blocks = ingress.value.cidr
      description = ingress.value.description
    }
  }

  dynamic "egress" {
    for_each = each.value.egress
    content {
      from_port   = egress.value.port
      to_port     = egress.value.port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr
      description = egress.value.description
    }
  }

  tags = {
    Name = "DE-AI-22-${each.key}-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

############################################
# Web -> Was 룰 적용, 포트 8000 오픈
############################################
resource "aws_security_group_rule" "web-to-was" {
  type                     = "ingress"

  # 이 규칙이 어느 SG에 붙는지 
  source_security_group_id = aws_security_group.sg["web"].id
  security_group_id        = aws_security_group.sg["was"].id
  from_port                = 8000
  to_port                  = 8000
  protocol                 = "tcp"
  description               = "App port from Web only"
}

############################################
# Was -> Db 룰 적용, 포트 3306 오픈
############################################
resource "aws_security_group_rule" "was-to-db" {
  type                     = "ingress"
  # 이 규칙이 어느 SG에 붙는지 
  source_security_group_id = aws_security_group.sg["was"].id
  security_group_id        = aws_security_group.sg["db"].id
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  description               = "MySQL from WAS only"
}

