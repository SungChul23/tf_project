# ────────────────────────────────────────────────
# RDS 보안 그룹
# ────────────────────────────────────────────────

resource "aws_security_group" "rds" {
  name        = "${local.cluster_name}-rds-sg"
  description = "RDS access from EKS Cluster"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Mysql from EKS Auto Mode WAS Pods and Nodes"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"

    #EKS 보안그룹 (aws_eks_cluster.main.vpc_config[0].security_groups)에서 들어오는 트래픽 허용
    security_groups = [
      aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
    ]

  }
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


    tags = {
      Name = "${local.cluster_name}-rds-sg"
    }
}