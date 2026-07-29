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