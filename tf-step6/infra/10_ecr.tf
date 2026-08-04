# ────────────────────────────────────────────────
# WEB ECR 저장소
# ────────────────────────────────────────────────

resource "aws_ecr_repository" "web" {

  name = "${local.cluster_name}/web"

  # 같은 이미지 태그를 다시 puch 할수 있다 -> 실습할떄만
  # 운영 환경에서는 버전번호, id를 통해 식별
  image_tag_mutability = "MUTABLE" # 이미지 태그 변경 가능 여부

  # 테라폼으로 destroy 실행시 이미지 부분 저장소와 함께 설정 할 것인지

  force_delete = true

  # 이미지 Push 할때 알려진 취약점들 자동 검사 처리
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = {
    Name = "${local.cluster_name}-ecr-web-repo"
  }
}

# ────────────────────────────────────────────────
# WAS ECR 저장소
# ────────────────────────────────────────────────

resource "aws_ecr_repository" "was" {

  name = "${local.cluster_name}/was"

  # 같은 이미지 태그를 다시 puch 할수 있다 -> 실습할떄만
  # 운영 환경에서는 버전번호, id를 통해 식별    
  image_tag_mutability = "MUTABLE" # 이미지 태그 변경 가능 여부

  # 테라폼으로 destroy 실행시 이미지 부분 저장소와 함께 설정 할 것인지

  force_delete = true

  # 이미지 Push 할때 알려진 취약점들 자동 검사 처리
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = {
    Name = "${local.cluster_name}-ecr-was-repo"
  }
}

# ────────────────────────────────────────────────
# ECR 관련 Lifecycle Policy
# ────────────────────────────────────────────────

#위에서 생성한 저장소 한 묶은 구성
locals {
  ecr_repos = {
    web = aws_ecr_repository.web
    was = aws_ecr_repository.was
  }
}

# 정책 : 태그와 상관없이 최근 push된 이미지 10개만 유지
#        오래된 이미지는 만료 (CI/CD 적용이후 확인)

resource "aws_ecr_lifecycle_policy" "main" {
  for_each = local.ecr_repos

  # 정책 영향을 받을 저장소 이름을 지정
  repository = each.value

  # 정책 구성 -> 현재 작성은 HCL 문법으로 작성 -> ECR 요구사항 JSON 형태로 변환 구성
  policy = jsonencode(
    {
      rules = [
        {
          #Lifecycle 규칙 실행 우선순위
          rulePriority = 1
          description  = "최신 이미지 10개만 유지"
          selection = {
            # 테그 존재여부 상관없음, 모든 이미지 대상
            tagStatus = "any"
            # 기준
            countNumber = 10
            # 저장된 이미지 개수가 기준을 초고화면 오래된 이미지
            countType = "imageCountMoreThan"
          }
          # 오래된 이미지는 삭제
          action = {
            type = "expire"
          }
        }
      ]
    }
  )


}