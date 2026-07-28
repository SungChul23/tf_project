# 실제로 생성할 AWS 리소스들을 정의하는 핵심 파일
# EC2, 보안그룹, VPC 등 "뭘 만들지"가 여기 다 들어감

# 1. 현재 리전의 VPC 서비스중 default 정보 조회 (data)
data "aws_vpc" "default" {
  default = true
}

# 2. 기본 VPC의 서브넷 정보 조회 (data)
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# 3. 보안그룹 생성 선언
resource "aws_security_group" "de-ai-22-IaC-sg" {
  name        = "de-ai-22-IaC-sg"
  description = "using_terraform_SG"
  vpc_id      = data.aws_vpc.default.id

  # 인바운드 : SSH (본인 IP만 허용 - 실무 권장 방식)
  ingress {
    description = "only SSH Traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 인바운드 : HTTP
  ingress {
    description = "only HTTP Traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 아웃바운드 : ALL ALLOW
  egress {
    description = "ALL ALLOW"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# AMI 조회 (아키텍처 필터 추가)
data "aws_ami" "get_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*"]
  }

  # 인스턴스 타입(x86_64 계열)과 아키텍처를 맞추기 위한 필터
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# 4. EC2 생성 선언 (2개)
resource "aws_instance" "de-ai-22-IaC-EC2" {
  ami           = data.aws_ami.get_amazon_linux.id
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id     = data.aws_subnets.default.ids[0]   # 우선 고정(a)로 진행

  vpc_security_group_ids = [
    aws_security_group.de-ai-22-IaC-sg.id
  ]

  tags = {
    Name = "de-ai-22-IaC-EC2-${count.index}"   # 인스턴스 구분용 인덱스 추가
  }

    count = 2

    # << - EOF . . EOF : 여러줄 문자열을 한번에 스크립트나 파일로 넘겨주는 형식
    #!/bin/bash 쉘을 통해서 아래 명령어 실행
    user_data = <<-EOF
      #!/bin/bash
      dnf install -y ec2-instance-connect
    EOF

}

/*
# 5. 탄력적 IP 선언 (EC2 2개 -> EIP 2개, 1:1 매칭)
resource "aws_eip" "de-ai-22-IaC-EIP" {
  count    = 2
  instance = aws_instance.de-ai-22-IaC-EC2[count.index].id
  domain   = "vpc"
}
*/