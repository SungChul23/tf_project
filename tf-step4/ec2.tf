# locals 구성 (서브넷,보안그룹)
locals {
  servers ={
    web ={
        subnet = aws_subnet.public.id
        sg = aws_security_group.sg["web"].id
    }

    was ={
        subnet = aws_subnet.private.id
        sg = aws_security_group.sg["was"].id
    }

     db ={
        subnet = aws_subnet.private.id
        sg = aws_security_group.sg["db"].id
    }
  }
}

# ami 조회
data "aws_ami" "get_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*"]
  }
}

# aws_instance 생성 선언 -> 반복
resource "aws_instance" "server" {
    for_each = local.servers
    ami = data.aws_ami.get_amazon_linux.id
    instance_type = var.instance_type
    subnet_id = each.value.subnet
    key_name = var.key_name
    
    vpc_security_group_ids = [
        each.value.sg
    ]

    tags = {
        Name = "DE-AI-22-${upper(each.key)}"
    }

    user_data = <<-EOF
        #!/bin/bash
        dnf install -y ec2-instance-connect
    EOF
        
}


# EIP 생성 선언 (단 오직 퍼블릭 즉 WEB EC2 만 사용)
/*
resource "aws_eip" "de-ai-22-IaC-EIP" {
    # EC2 선언  - > web 용
    instance = aws_instance.server["web"].id

    #네트워크
    domain = "vpc"
}
*/


# NAT G/W
resource "aws_eip" "nat" {
    domain = "vpc"
    tags = {
      Name = "de-ai-22-EIP-NAT"
    }
  
}
resource "aws_nat_gateway" "de-ai-22-IaC-EIP-NAT" {
    allocation_id = aws_eip.nat.id
    subnet_id = aws_subnet.public.id # 퍼블릭 서브넷에 배치

    tags = {
      Name = "de-ai-22-nat-g/w"
    }

    # 명시적 의존성 -> IGW 선행 생성후 진행
    depends_on = [ 
        aws_internet_gateway.company
     ]
  
}