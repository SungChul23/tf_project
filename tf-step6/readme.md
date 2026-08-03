# 목표
- v1 버전기반 쿠버네티스 도입, 구조 변경, 새로운 개념 정리(운영/관리)
- 쿠버네티스를 디테일하게 직접 구성 OR auto mode로 구성 (관리파트)
-> EKS , ECR 활용

# 쿠버네티스
- 컨테이너를 여러 서버에 배치, 장애 발생시 복구, 트래픽에 따라 확장/감소하는 시스템
- 수많은 컨테이너화된 어플리케이션 배포, 확장, 관리를 자동화하는 오픈소스 기반의 `컨테이너 오케스트레이션 표준 플랫폼`
- 여러 서버(물리/가상)에 걸쳐 컨테이너의 그룹화, 무중단 배포, 로드밸런싱, 셀프힐링 등 을 수행
- 클러스터 단위로 작동
    - 구성
        - 전체 클러스터의 두뇌 역할 구동 : 컨트롤 플랜 (마스터 노드) -> auto mode시 자동 구성
        - 실제 컨테이너 어플리케이션 구동 : 데이터 플랜 (워커 노드) <- auto mode 구성시 집중 파트

# 쿠버네티스 구조
- 쿠버네티스 중심 기반 구성

![쿠버네티스 중심 기반 구성](k8s_image_2.png)


- AWS EKS 기반 구성

![쿠버네티스 중심 기반 구성](k8s_image_1.png)

- 트래픽 흐름도
```
                         Internet
                            │
                            ▼
                 AWS Application Load Balancer
                            │
                      Kubernetes Ingress
                            │
                            ▼
                    WEB Service(ClusterIP)
                            │
                ┌───────────┴───────────┐
                ▼                       ▼
          WEB Pod 1                 WEB Pod 2
        Nginx Container           Nginx Container
                │
                └───────────┬───────────┘
                            │
                            ▼
                    WAS Service(ClusterIP)
                            │
                ┌───────────┴───────────┐
                ▼                       ▼
          WAS Pod 1                 WAS Pod 2
        FastAPI Container         FastAPI Container
                │                       │
                └───────────┬───────────┘
                            │
                            ▼
                     Amazon RDS MySQL
                      Multi-AZ 구성
```