# ============================================================
# EKS Auto Mode 클러스터 생성
# Auto Mode: 컴퓨트(노드)·네트워킹·스토리지·로드밸런서를
#            AWS가 대신 자동으로 프로비저닝/관리해주는 모드
# ============================================================

resource "aws_eks_cluster" "main" {
  # --- 기본 정보 ---
  name    = local.cluster_name
  version = var.kubernetes_version # 예: "1.35"

  # EKS 컨트롤 플레인이 AWS 리소스(노드/LB/스토리지 등)를 다룰 때 쓰는 IAM Role
  # (iam.tf에서 만든, principal이 eks.amazonaws.com인 그 Role)
  role_arn = aws_iam_role.eks_cluster.arn

  # Auto Mode를 쓰므로 vpc-cni, coredns 같은 기본 addon을
  # 별도로 직접 설치하지 않음 (AWS가 알아서 관리)
  bootstrap_self_managed_addons = false

  # --- 클러스터 접근 권한 관리 방식 ---
  access_config {
    authentication_mode = "API" # 최신 방식인 EKS Access Entry API로 인증/인가 관리

    # 이 클러스터를 terraform apply로 만든 IAM 사용자/Role에게
    # 최초 관리자 권한을 자동으로 부여
    # (오늘 겪었던 "kubectl 인증 안 됨" 문제를 방지하는 설정,
    #  Managed Node Groups 방식의 enable_cluster_creator_admin_permissions와 동일한 목적)
    bootstrap_cluster_creator_admin_permissions = true
  }

  # --- Auto Mode: 컴퓨트(노드) 자동 관리 설정 ---
  compute_config {
    enabled = true # 노드(EC2)를 AWS가 자동으로 프로비저닝하게 함

    # 어떤 용도의 노드풀을 쓸지 지정
    node_pools = [
      "gerneral-purpose", # 일반 워크로드용 (WEB, WAS 등 우리 앱 Pod가 뜨는 곳)
      "system"            # 클러스터 운영에 필수적인 시스템 Pod 전용
    ]

    # Auto Mode가 노드(EC2)를 새로 만들 때, 그 노드에 붙일 IAM Role
    # (iam.tf에서 만든, principal이 ec2.amazonaws.com인 그 Role)
    node_role_arn = aws_iam_role.eks_auto_node.arn
  }

  # --- 쿠버네티스 내부 네트워크 설정 ---
  kubernetes_network_config {
    # Service(ClusterIP)들이 사용하는 가상 IP 대역.
    # VPC/Pod/Node가 쓰는 CIDR(10.0.0.0/16)과 절대 겹치면 안 됨
    # → 클러스터 내부(kube-proxy)에서만 쓰이는 별도의 가상 주소 공간
    service_ipv4_cidr = "172.20.0.0/16"

    elastic_load_balancing {
      enabled = true # Service(LoadBalancer 타입)/Ingress 생성 시 ALB/NLB 자동 연동
    }
  }

  # --- 영구 스토리지(EBS) 자동 관리 설정 ---
  storage_config {
    block_storage {
      enabled = true # PVC(PersistentVolumeClaim) 생성 시 EBS 볼륨을 자동으로 만들어 Pod에 연결
    }
  }

  # --- EKS가 사용할 VPC/네트워크 및 API 엔드포인트 접근 설정 ---
  vpc_config {
    # 노드/Pod가 뜰 서브넷 = Private App 서브넷 전체(가용영역별로 모두)
    # ⚠ 오타 주의: values(...) 가 맞음 (value 아님) — 그대로 두면 plan/apply 시 에러 남
    subnet_ids = values(aws_subnet.app)[*].id

    endpoint_private_access = true # VPC 내부(노드 등)에서 EKS API 엔드포인트 접근 허용
    endpoint_public_access  = true # 로컬 PC 등 외부(kubectl, CLI)에서 EKS API 엔드포인트 접근 허용

    # public 엔드포인트에 접근 가능한 IP 대역 제한
    # 지금은 제한 없이 모든 대역 허용 (실습/개발 단계라 편의 우선, 운영에선 좁히는 게 안전)
    public_access_cidrs = var.cluster_endpoint_public_access
  }

  # --- 컨트롤 플레인 로그를 CloudWatch로 전송 ---
  enabled_cluster_log_types = [
    "api",                # API 서버에 들어온 요청 로그
    "audit",               # 누가 언제 무슨 작업을 했는지 감사 로그
    "authenticator",        # IAM 인증 처리 로그
    "controllerManager",    # Deployment/ReplicaSet 등 컨트롤러의 상태 조정 로그
    "scheduler"              # Pod가 어느 노드에 배치됐는지에 대한 로그
  ]

  tags = {
    Name = local.cluster_name
  }

  # 아래 리소스들이 먼저 완전히 준비된 뒤에 EKS 클러스터 생성을 시작하도록 강제
  # (IAM 정책이 안 붙은 상태로 클러스터부터 만들면 권한 에러가 날 수 있으므로)
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster,   # 클러스터 Role에 5개 정책 부착 완료
    aws_iam_role_policy_attachment.eks_auto_node, # 노드 Role에 정책 부착 완료
    aws_route_table_association.app,               # 노드가 들어갈 서브넷의 라우팅 준비 완료
    aws_cloudwatch_log_group.eks                    # 로그를 받을 CloudWatch 그룹 준비 완료
  ]
}


# ────────────────────────────────────────────────
# (TODO) Metrics Server addon
# → HPA가 CPU/메모리 사용량을 보고 Pod 개수를 조절하려면 필요한 컴포넌트
# 아직 미구현
# ────────────────────────────────────────────────
 resource "aws_eks_addon" "metrics_server" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "metrics-server"

  # 이미 설정한 경우 ? -> 오버라이트
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

    tags = {
    Name = "${local.cluster_name}-metrics-server-addon"
  }
 }


# ────────────────────────────────────────────────
# (TODO) 추가 IAM 사용자/Role에 클러스터 접근 권한 등록
# → bootstrap_cluster_creator_admin_permissions 로 받은 관리자 권한 외에
#   다른 팀원 계정에도 접근 권한을 열어주려면 필요
# 아직 미구현
# ────────────────────────────────────────────────
# resource "aws_eks_access_entry" "admin" {
# }
# resource "aws_eks_access_policy_association" "admin" {
# }