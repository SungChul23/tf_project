# 실제로 생성할 AWS 리소스들을 정의하는 핵심 파일
# EC2, 보안그룹, VPC 등 "뭘 만들지"가 여기 다 들어감

# 1. 현재 리전의 VPC 서비스중 default 정보 조회 (data)
# - 현재 리전의 VPC 서비스 중 default 정보 조회 하라 -> data.aws_vpc.default.id 참조

data "aws_vpc" "default" {
  default = true

}

# 2. 기본 VPC의 서비스 정보 조회 하라 (data)
# - n개의 서브넷이 존재하므로 이름 values에 담아라

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

}

# 3. 보안그룹 생성 선언 - EC2 진입하는 것에 대한 인-아웃바운드 Port를 설정해서 접근을 제한
# 생성 = resource

resource "aws_security_group" "de-ai-22-IaC-sg" {
  name        = "de-ai-22-IaC-sg"
  description = "using_terraform_SG"
  # 보안 그룹은 VPC에 종속되어서 구성됨
  # id - > 리소스명 - 해시값 (중복 x , 고유값)

  # 보안그룹은 VPC 안에서만 존재할 수 있는 리소스
  vpc_id = data.aws_vpc.default.id

  # 인바운드 : only SSH Traffic
  ingress {
    description = "only SSH Traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 인바운드 : only HTTP Traffic
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


# AMI 조회 
data "aws_ami" "get_amazon_linux" {
    # 최신설정
    most_recent = true

    # 소유자
    owners = ["amazon"]
    
    filter {
      name = "name"
      values = ["al2023-ami-*"]
    }
}

# 4. EC2 생성 선언
resource "aws_instance" "de-ai-22-IaC-EC2" {
  #AMI
  ami = data.aws_ami.get_amazon_linux.id

  #인스턴스 유형
  instance_type = var.instance_type

  # Key_name
  key_name = var.key_name

  # 서브넷
  subnet_id = data.aws_subnets.default.ids[0]

  # 보안그룹
  vpc_security_group_ids = [
    aws_security_group.de-ai-22-IaC-sg.id
  ]

  # EBS 스토리지 생략

  #테그 지정
  tags = {
    Name = "de-ai-22-IaC-EC2"
  }

}
# 5. 탄력적 IP 선언
resource "aws_eip" "de-ai-22-IaC-EIP" {
    # EC2 선언 
    instance = aws_instance.de-ai-22-IaC-EC2.id

    #네트워크
    domain = "vpc"
  
}