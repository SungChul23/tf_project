###################################
# web ec2용 -> launch template 요소(ASG 내에서 사용)를 사용하여 생성됨
###################################

resource "aws_launch_template" "web" {
  name_prefix   = "${local.project}-WEB-"
  image_id      = data.aws_ami.amazone_linux.id
  instance_type = var.instance_type

  # SSM 접속을 위해 IAM 역할 매칭
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_ssm.name
  }

  # 보안그룹 지정
  vpc_security_group_ids = [aws_security_group.web.id]

  # 서버 구성후 초기 작업 (쉘 스크립트 실행)
  user_data = base64encode(templatefile("${path.module}/userdata-web.sh.tftpl", {
    # web->프록시->internal ALB
    # 해당 값을 가져가서 nginx conf 파일을 완성함
    internal_alb_dns = aws_lb.internal.dns_name
  }))
  # 태그
  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tag, {
      Name = "${local.project}-WEB"
      Tier = "WEB"
    })
  }

  # 삭제하기전에 생성해라
  lifecycle {
    create_before_destroy = true

  }

  # 순서: 새 리소스 먼저 생성 → 그 다음 기존 리소스 삭제
  # 항상 최소 하나의 리소스가 존재해서 끊김이 없음 
}



###################################
# was ec2용 -> launch template 요소(ASG 내에서 사용)를 사용하여 생성됨
###################################

resource "aws_launch_template" "was" {

  name_prefix   = "${local.project}-WAS-"
  image_id      = data.aws_ami.amazone_linux.id
  instance_type = var.instance_type


  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_ssm.name
  }


  vpc_security_group_ids = [aws_security_group.was.id]



  user_data = base64encode(templatefile("${path.module}/userdata-was.sh.tftpl", {
    # rds 세팅값 설정
    db_host = aws_db_instance.mysql.address
    db_port = aws_db_instance.mysql.port
    db_name = var.db_name
    db_user = var.db_username

  }))
  # 태그
  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tag, {
      Name = "${local.project}-WAS"
      Tier = "WAS"
    })
  }

  # 삭제하기전에 생성해라
  lifecycle {
    create_before_destroy = true

  }
}
