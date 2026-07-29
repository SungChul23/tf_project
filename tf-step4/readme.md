# 목표 시스템
```
                    Internet
                        │
                Internet Gateway
                        │
                Public Route Table
                        │
      ┌─────────────────┴─────────────────┐
      │                                   │
 Public Subnet (10.0.1.0/24)        Private Subnet (10.0.2.0/24) <- ssm Manager 방식
      │                                   │
      │                                   │
 ┌────────────┐                    ┌────────────┐
 │ Web EC2    │                    │ WAS EC2    │
 │ nginx      │     -(SSH)->       │ FastAPI    │
 └────────────┘                    └────────────┘
                                          │
                                    ┌────────────┐
                                    │ DB EC2     │
                                    │ mysql      │
                                    └────────────┘
                                          
```  

# 리소스 구성
AWS
L VPC
    L Internet Gateway
        L public Route Table
            L Public Subnet
                L EC2 (Web) - SG (22, 80, 443) - EIP
    -------------------------------------------------
    L NAT Gateway
        L Private Route Table
            L Private Subnet
                L EC2 (Was) - SG (22, 8000)
                L EC2 (Db)  - SG (22, 3306)

# 예상되는 작업
- 퍼블릭 서브넷 활용
    - 반복 표현으로 구성
        - SG는 반복 구성 (locals, for_each, dynamic 활용)
        - EC2는 반복 구성 (locals, for_each, dynamic 활용)

- 프라이빗 서브넷 구성
    - Private Subnet
    - Private Route Table
    - association
    - EC2 조정

# 보안 그룹 구성
- sg.tf 생성
- ingress 파트가 반복됨
    - EC2 (Web) 
        ```
            # ingress 3회반복 -> locals에서 값 정의(상수), for_each(반복데이터주입), dynamic을 통해 블록반복표현
            ingress {
              ..  22  ..
            }
            ingress {
              ..  80  ..
            }
            ingress {
              ..  443  ..
            }
        ```
- 작성
    - terraform fmt
    - terraform validate
    - terraform plan
        - 의도한 대로 네이밍, 리소스 구성등 잘 계획되었는지 확인

- web -> was, was는 오직 web에서만 tcp 8000 포트로만 오픈된다. rule 구성
    - 대시보드 > 해당 보안그룹 > 인바운드 > 8000 포트의 소스 탭 > 접근 가능한 보안 그룹(WEB)이 명시, cidr x

- was -> db,  db는 오직 was에서만 tcp 3306 포트로만 오픈된다. rule 구성
    - 대시보드 > 해당 보안그룹 > 인바운드 > 3306 포트의 소스 탭 > 접근 가능한 보안 그룹(WAS)이 명시, cidr x


# VPC Private Subnet 구성
- 서브넷, 라우트 테이블, 서브넷-라우트테이블 연결
- VPC > 리소스맵 > private 서브넷 연결 다이어 그램 확인

```
VPC (10.0.0.0/16) - de-ai-22-company
│
├── Public Subnet (10.0.1.0/24)
│     └── Web EC2 (외부 노출, IGW 경로, EIP 부착)
│
└── Private Subnet (10.0.2.0/24)
      ├── WAS EC2 (내부 전용, web에서만 22/8000 허용)
      └── DB EC2 (내부 전용, was에서만 3306 허용)

```

# EC2 구성 - 각각 적절한 서브넷으로 배치 생성
- ec2.tf
    - 작성
    - terraform apply
    - AWS Console > EC2 > 본인 EC2-..WEB > 연결 > 웹브라우저에서 EC2 인스턴스 연결
    - xx.pem Web Ec2 서버에 업로드
    - WEB EC2 터미널
        ```
            # 권한 조정
            $ chmod 400 DE-AI-25-TEST.pem

            # WAS 서버에 SSH로 접속 (WEB-to-WAS)
            $ ssh -i DE-AI-25-TEST.pem ec2-user@10.0.2.180
            ---
            The authenticity of host '10.0.2.180 (10.0.2.180)' can't be established.
            ED25519 key fingerprint is SHA256:/wqhJhz9FChYYmUTq/jeWthAgosrqUwW/qEgdX6kEW4.
            This key is not known by any other names
            Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
            Warning: Permanently added '10.0.2.180' (ED25519) to the list of known hosts.
            ,     #_
            ~\_  ####_        Amazon Linux 2023
            ~~  \_#####\
            ~~     \###|
            ~~       \#/ ___   https://aws.amazon.com/linux/amazon-linux-2023
            ~~       V~' '->
                ~~~         /
                ~~._.   _/
                    _/ _/
                _/m/'
        ```
    
# NAT Gateway 구성
- private subnet에 존재하는 EC2 리소스 내에서 특정 패키지를 어떻게 설치, 업그레이드 가능할까? => NAT Gateway
- 작업
    - NAT Gateway 은 public subnet 소속, 기능은 제한적 통신(단방향적, pull만 가능)
        - EIP 생성 선언
        - NAT Gateway 생성 선언 (EIP 연결)
    - private route table에 라우트 설정 NAT Gateway
        - private route table에 route 기능 설정하여 NAT Gateway와 연결