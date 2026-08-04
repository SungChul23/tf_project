# AWS CloudWatch Logs 관련 설정

# k8s 컨트롤 플랜의 로그를 CloudWatch Logs로 보내기 위해 Log Group 생성
resource "aws_cloudwatch_log_group" "eks_cluster_logs" {
  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = 7

  tags = {
    Name = "${local.cluster_name}-cluster-logs"
  }

}