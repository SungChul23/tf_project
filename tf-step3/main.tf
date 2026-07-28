# AMI 조회 (무조건 해야하나 흠)
data "aws_ami" "get_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*"]
  }
}

# 보안그룹 생성
resource "aws_security_group" "de-ai-22-IaC-sg" {
    name = "de-ai-22-IaC-sg"
    description = "using_terraform_sg"

    # 커스텀 VPC 사용
    vpc_id = aws_vpc.de-ai-22-company.id

    # 인바운드: SSH (22)
  ingress {
    description = "only SSH Traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 인바운드: HTTP (80)
  ingress {
    description = "only HTTP Traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 아웃바운드: ALL ALLOW
  egress {
    description = "ALL ALLOW"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "de-ai-22-IaC-sg"
  }
}

# EC2 인스턴스 생성
resource "aws_instance" "de-ai-22-IaC-EC2" {
    ami = data.aws_ami.get_amazon_linux.id
    instance_type = var.instance_type
    key_name = var.key_name

    # 커스텀 으로 만든 서브넷 id 할당
    subnet_id = aws_subnet.public.id

    # 커스텀 VPC 보안그룹 적용
    vpc_security_group_ids = [
        aws_security_group.de-ai-22-IaC-sg.id
    ]

    tags = {
        Name = "de-ai-22-IaC-EC2"
    }
}

# 탄력적 IP
resource "aws_eip" "de-ai-22-IaC-EIP" {
    instance = aws_instance.de-ai-22-IaC-EC2.id
    domain = "vpc"

    # 인터넷 GW가 완전히 생성된 후 EIP가 할당 되어야함
    depends_on = [ aws_internet_gateway.company ]
    
    tags = {
        Name = "de-ai-22-IaC-EIP"
    }
}


# VPC ➔ 서브넷 ➔ IGW ➔ 라우터 순으로 네트워크 생태계가 만들어지고,
# 보안그룹과 EC2가 해당 퍼블릭 서브넷 내부에 배치된 후,
# 마지막으로 EIP가 생성되어 EC2에 고정 IP로 연결