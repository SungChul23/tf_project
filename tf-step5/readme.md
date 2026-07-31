# 구성 버전
## V1 
- infrastructure Enginnering : 운영 가능한 인프라 구축
```
Terraform -> Production AWS -> 3-tier -> Multi AZ(멀티존) -> ALB(어플리케이션 로드밸런서) -> ASG(오토스케일링그룹) -> RDS

SSM System Manager를 통해서 ec2에 접속 (pem 배제)
```

## V2
- Plafrom Enginnering : 컨테이너 플랫폼 구축 -> 쿠버네티스 기반으로 전체 재구성
```
Terraform -> EKS -> Container -> Deployment -> Serive -> ingress 
```

## V3
- Devops : CI/CD
```
Github -> GitAction/ArgoCD -> ECR -> EKS
```

## V4
- Obserability : 운영 및 모니터링
```
Prometheus -> Grafana -> Metrics -> Alert (슬랙등..)
```

# Infrastructure Enginnering : 운영 가능한 인프라 구축
- 특징
    - 테라폼으로 운영 인프라 전체를 구축    
    - 고가용성
        - Web1이 장애 발생/부하 높게 걸리면 (CPU 50% 초과) -> `ALB`가 Web2로 트레픽 우회
        - 트레픽 분산 > 장애 대응 전략
    - 확장성
        - 접속 증가/감소 -> 직접 ec2 개수 증가/감수 -> 자동관리 구성
        - `AGS(Auto Scaling Group)` == 쿠버네티스 replica
    - 불변 인프라
        - Ec2 구성 => `Launch Template` 사용 > 신규 Ec2 생성 > 자동 설치 > 서비스 자동 시작
        - 서버 내용이 수정 => Launch Template 반응 => EC2 순차적 교체 => Ec2 오드버전 순차 삭제 (무중단 구성 ) == 쿠버네티스의 컨테이너 교체
    - 로드 밸런싱
        - 고가용성에 대한 구체적 시나리오
        - 버전별 
            - v0(기존) : client -> web
            - v1(금일) : client -> ALB(EIP 연결) -> web1 or web2
            - v2(차주) : Ingress -> Serive -> pod
    - 데이터베이스 분리 운영
        - db는 AWS 전용 rds 서비스 사용 -> 생성시간이 대략 10분 소요
    - 운영형 아킥텍쳐        
    - 쿠버네티스로 자연스럽게 확장 연동 대체 가능한 구조
        - 각 파트별 대체 가능

# 구성도
- 트래픽 이동(api 요청, 웹페이지 요청, request)
```
Internet (외부망, 퍼블릭, 인터넷)
   │
Public ALB (EIP, 도메인, 퍼블릿 서브넷)
   │
WEB Auto Scaling Group (ASG, 최소 2개 구성, 확장성 조건 명시, 최대 n개)
├─ WEB EC2 / AZ-a (가용영역-a -> 서브넷 a존)
└─ WEB EC2 / AZ-c (가용영역-c -> 서브넷 c존)
   │
Internal ALB (프라이빗 서브넷, web<->was, 로드밸런싱)
   │
WAS Auto Scaling Group
├─ WAS EC2 / AZ-a
└─ WAS EC2 / AZ-c
   │
RDS MySQL Multi-AZ (고가용성, db 용량이 부족 -> 자동증가 설정-> AWS RDS 자동 처리, 활성화 하면 적용)
├─ Primary
└─ Standby
```