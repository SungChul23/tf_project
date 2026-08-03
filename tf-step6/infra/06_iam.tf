# ============================================================
# EKS 관련 IAM Role 2개
#   1) eks_cluster    - EKS 컨트롤 플레인(Auto Mode)이 사용하는 Role
#   2) eks_auto_node  - 실제 노드(EC2)가 사용하는 Role
# 각 Role은 "누가 빌려 쓸 수 있는가(신뢰정책)" → "Role 생성" → "무엇을 할 수 있는가(정책 부착)"
# 3단계로 구성됨
# ============================================================


# ------------------------------------------------------------
# 1) EKS 컨트롤 플레인용 Role
# ------------------------------------------------------------

# [1단계: 신뢰정책] "누가 이 Role을 빌려 쓸 수 있는가"
# → AWS의 EKS 서비스(eks.amazonaws.com) 자체만 이 Role을 assume 가능
data "aws_iam_policy_document" "eks_cluster_assume" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",   # Role을 임시로 빌려 쓸 수 있는 권한
      "sts:TagSession"    # 빌려 쓰는 세션에 태그를 붙일 수 있는 권한
    ]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

# [2단계: Role 생성] 위 신뢰정책을 가진 실제 IAM Role
resource "aws_iam_role" "eks_cluster" {
  name               = "${local.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume.json
}

# EKS Auto Mode가 컴퓨트/네트워크/스토리지/로드밸런서를 "대신 자동으로 관리"하기 위해
# 필요한 AWS 관리형 정책 5종 (이름=arn 형태의 맵으로 정리)
locals {
  eks_auto_cluster_policies = {
    cluster        = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"        # 클러스터 운영 기본 권한
    compute        = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"        # 노드 자동 프로비저닝
    block_storage  = "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicyV2" # EBS 볼륨 자동 관리
    load_balancing = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"  # ALB 등 자동 생성/연결
    networking     = "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"     # VPC CNI 등 네트워크 자동 구성
  }
}

# [3단계: 정책 부착] 위 5개 정책을 eks_cluster Role 하나에 전부 붙임
# for_each로 맵을 순회 → 5번 반복 실행되는 것과 동일 (Role은 여전히 1개)
resource "aws_iam_role_policy_attachment" "eks_cluster" {
  for_each = local.eks_auto_cluster_policies

  role       = aws_iam_role.eks_cluster.name
  policy_arn = each.value
}


# ------------------------------------------------------------
# 2) 노드(EC2)용 Role
# ------------------------------------------------------------

# [1단계: 신뢰정책] 이번엔 주체가 다름
# → EC2 서비스(ec2.amazonaws.com), 즉 "실제 노드 인스턴스"만 이 Role을 assume 가능
data "aws_iam_policy_document" "eks_auto_node_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# [2단계: Role 생성]
resource "aws_iam_role" "eks_auto_node" {
  name               = "${local.cluster_name}-auto-node-role"
  assume_role_policy = data.aws_iam_policy_document.eks_auto_node_assume.json
}

# 노드에게는 딱 필요한 최소한의 권한만 부여 (최소 권한 원칙)
# - worker: 클러스터에 정상적으로 등록되고 동작하기 위한 최소 권한
# - ecr   : ECR에서 이미지를 "받아오기(Pull)"만 가능, 올리기(Push)는 불가
#           → 노드는 이미지를 실행만 하면 되므로 Push 권한이 필요 없음
locals {
  eks_auto_node_policies = {
    worker = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy"
    ecr    = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
  }
}

# [3단계: 정책 부착] 위 2개 정책을 eks_auto_node Role 하나에 부착
resource "aws_iam_role_policy_attachment" "eks_auto_node" {
  for_each = local.eks_auto_node_policies

  role       = aws_iam_role.eks_auto_node.name
  policy_arn = each.value
}