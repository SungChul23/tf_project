############################################
# RDS Subnet Group - 서로 다른 AZ의 DB 서브넷 사용
############################################
resource "aws_db_subnet_group" "main" {
  name       = "de-ai-22-db-subnet-group"
  subnet_ids = [for subnet in aws_subnet.db : subnet.id]

  tags = { Name = "${local.project}-DB-SUBNET-GROUP" }
}

############################################
# RDS MySQL Multi-AZ
# manage_master_user_password=true:
# 비밀번호를 코드에 저장하지 않고 AWS Secrets Manager가 관리
############################################
resource "aws_db_instance" "mysql" {
  identifier = "de-ai-22-mysql-v2"

  engine         = "mysql"
  instance_class = var.db_instance_class

  # 기본
  allocated_storage = 20

  # 최대
  max_allocated_storage = 100

  storage_type = "gp3"

  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username

  # 관리자 비번은 AWS Secrets Manager 사용하도록 -> 유료
  manage_master_user_password = true

  # 장애 대응, 오류 발생시 복제본 생성 서비스 유지
  multi_az = true

  # 퍼블릭 IP X
  publicly_accessible = false
  # 서브넷 그룹
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period = 7
  backup_window           = "18:00-19:00"
  maintenance_window      = "sun:19:00-sun:20:00"


  # 삭제 방지 기능 안함
  deletion_protection = false
  skip_final_snapshot = true
  apply_immediately   = true

  tags = { Name = "${local.project}-MYSQL" }
}