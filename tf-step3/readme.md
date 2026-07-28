# 목표
- 회사 전용으로 클라우드내 네트워크 구축 -> VPC
- 현재 EC2는 defaults VPC 사용 -> 전용 VPC로 직접 생성하여 적용
- [v] VPC만 구축 (가장 먼서 선행할 작업)
    -> [v] EC2에 커스텀 VPC 연결 하여 인프라구성 
    -> web(public subnet), was/db(private subnet) 확장 + NAT gateway, SSH Manager, IAM Role
    -> 소스코드, 쿠버네티스, CI/CD
    -> 대시보드 (그라파타, 프로메테우스,..)

# 구성
    - AWS
        - VPC
        - CIDR
        - Public/Private Subnet
        - Internet Gateway
        - NAT Gateway
        - Route Table/Route Table Assoication
        - ..

# VPC (Virtual Private Cloud)
## 정의
- AWS(클라우드 생태계) 안에 내가(개인/기업) `직접 만드는 사설 네트워크`
- AWS 안에 나만(개인/기업) 사용하는 독립된(격리된) 네트워크 공간

## 현실세계 비유
- AWS : 도시/국가(생태계)
- VPC : 수많은 아파트 단지 (클라우드 관점 : 개인/회사 단독 사용)
- subnet : 동(101동, 102동,..)
- EC2 : 각 집(세대, 101호, 102호...)
- Internet Gateway : 아파트 정문 (외부 통신 가능, 트레픽 나가고, 들어오고 가능)
    - Subnet은 public 형태(개방)   
- Route table : 안내 표지판 (주소, 길, 방향)
- Security Group : 각 세대(집) 현관문 보안장치( 출입 통제 -> 포트/IP 제약(인바운드,아웃바운드))
- NACL(Network Access Control List) : 아파트 동/단지 출입 통제 (VPC를 위한 보안 계층)
--------------
- NAT Gateway : 
    - Private Subnet을 위해서 구성
        - 외부에서 Private Subnet으로 접근 x
        - s/w 설치를 해야하는 경우, 소스코드 획득 등 내부에서 외부의 자원을 가져올 필요가 있음(pull)
        - 이를 위해서 NAT gateway 가 필요함

## 구성원 
### VPC
    - Default VPC
        - 리전별 n개 구성 (통상 자동으로 만들어져 있음)
        - EC2 구성시 바로 사용 가능(퍼블릭 기본 세팅)
        - 학습, 테스트시 유용
        - 나만의 VPC x
    - [v] Custom VPC
        - 하위 구성원들 직접 구성(설계)
        - 운영환경등 활용
        - 나만의 VPC o

### CIDR
    - VPC 구성시 IP 주소 범위 지정
    ```
        # 설정
        10.0.0.0/16
        ---
        # 해석 : 앞에 16비트(2자리) 고정/ 뒤의 2자리만 커스텀가능 
        # 0 ~ 255 사용가능 -> 256*256 조합 -> 가용한 IP는 65,536개 사용가능(실제 예약값 존재함)
        10.0.0.10    -> OK
        10.0.1.10    -> OK
        10.0.255.254 -> OK

        10.1.0.10    -> 불가
    ```

### 서브넷
    - VPC를 작은 네트워크로 나눈것
        ```
            VPC
            10.0.0.0/16
            L Public   : 10.0.1.0/24
            L Private  : 10.0.2.0/24
            
            ---
            Public 대역
                - 앞의 3자리 고정 => 나올수 있는 IP의 가지수는 이론상 10.0.1.0 ~ 10.0.1.255 : 256개
                    - 2^(32-24)   => 가지수
                - AWS 예약 IP (5개) -> 사용 x
                    - 10.0.1.0 : 네트워크 주소
                    - 10.0.1.1 : AWS VPC 라우터 주소
                    - 10.0.1.2 : AWS DNS 서버 주소
                    - 10.0.1.3 : AWS 미래 사용을 위한 예약용 주소
                    - 10.0.1.255 : 브로드케스트 주소
                - 최종 : 사용 개수 256-5 = `251개 가용 가능한`

        ```
    - 종류
        - 퍼블릭 서브넷
            - 외부 인터넷과 직접 통신이 가능한 구역
            - 인터넷 게이트웨이로 향하는 라우트 경로가 존재
            - 외부에서 접속 가능한 퍼블릭 IP 가짐 ([*]web <-> was <-> db )
            - 배치 : web서버, ALB(로드벨런서), Bastion Host(private 서브넷 접속), ..
            ```
                Internet <-> IGW <-> Route Table <-> Public Subnet <-> EC2                    
            ```
        - 프라이빗 서브넷
            - 외부 인터넷 망과 격리되어 내부 통신만 가능한 안전한 구역
            - 외부에서 이 구역으로 접속 불가(모두 차단)
            - 단 NAT 게이트웨이를 통해서 외부로 나가는 통신 가능 (Pull)
            - 배치 : EKS 워커노드(worker node), db(rds, 직접설치),  백엔드 서버(was)
            ```
                Internet                       X  Route Table <-> Public Subnet <-> EC2
                Internet  <-(pull) NAT Gateway <-> Route Table <-> Public Subnet <-> EC2
            ```

### 게이트웨이
    - 인터넷과 연결하는 문
        ```
            # 큰 틀
            인터넷 <-> IGW <-> VPC
        ```
    - 종류
        - IGW(Internet Gateway)
            - VPC와 인터넷 연결, 양방향, 관문
            - 퍼블릭 서브넷의 위치한 리소스(ec2등)와 인터넷간 데이터를 주고받을 수 있다
        - NAT Gateway
            - 프라이빗 서브넷의 위치한 리소스(ec등)에서 외부 인터넷의 데이터를 다운로드(라이브러이 업데이트, 도커 이미지 패치, ..)
            - 외부에서 프라이빗 네트워크 내부로 들어오는 접근은 완전 차단 (일방향)

### 라우팅 테이블
    - 네비게이션/이정표/안내
    - 패킷(데이터 요청/응답)이 어디로 갈지 결정하는 안내 표지판
        ```
            목적지         
            10.0.0.0/16     local
            0.0.0.0/0       IGW
        ```
    - `패킷`이 `목적지 IP를 찾아갈수 있도록 안내 규칙 집합`
    - 예)
        - 퍼블릭 - 라우팅 테이블 : 0.0.0.0/0 => IGW 보내라
        - 프라이빗 - 라우팅 테이블 : 0.0.0.0/0 => NAT Gateway 보내라

### 보안 방화벽
    - 구성
    ```
                [ Internet / External ]
                        │
                        ▼
            ┌──────────────────────────────┐
            │        Subnet Boundary       │
            │   ┌──────────────────────┐   │
            │   │ Network ACL (NACL)   │ ⬅️ 1차 검문 (Stateless, 서브넷 단위)
            │   └──────────┬───────────┘   │
            │              │               │
            │              ▼               │
            │   ┌──────────────────────┐   │
            │   │ Security Group (SG)  │ ⬅️ 2차 검문 (Stateful, 인스턴스/ENI 단위)
            │   └──────────┬───────────┘   │
            │              │               │
            │              ▼               │
            │   ┌──────────────────────┐   │
            │   │     EC2 Instance     │ ⬅️ 최종 도착지
            │   └──────────────────────┘   │
            └──────────────────────────────┘
    ```
    - 보안 그룹 (Security Group)
        - 대상 : EC2 인스턴스, EKS 노드 단위, POD 대상
        - 특징 : 허용/허가(allow) 규칙 설정, 기본적 모든 트레픽 차단, 필요한 것만 개방
        - 종류 : 인바운드, 아웃바운드
    - 네트워크 ACL(NACL)
        - 대상 : 서브넷 전체 단위에 적용되는 방화벽
        - 특징 : 허용(allow), 거부(deny) 규칙 모두 설정 가능


# 망구성
## 개발, 운영, 테스트등 분리 전략
```
AWS
 ├── VPC-A (개발)
 │      ├── EC2
 │      ├── RDS
 │      └── ALB
 │
 ├── VPC-B (운영)
 │      ├── EC2
 │      └── RDS
 │
 └── VPC-C (테스트)
```

## 일반적 구성(용도제외, 요소별 구성)
```
                  Internet
                      │
              Internet Gateway
                      │
               ┌──────────────┐
               │     VPC      │
               │10.0.0.0/16   │
               └──────────────┘
                 │          │
        ┌────────┘          └────────┐
        │                            │
 Public Subnet                 Private Subnet
10.0.1.0/24                   10.0.2.0/24
        │                            │
      EC2(Web)                   EC2(DB, WAS)
        │                            │
    Public IP                    Private IP
```

## 게이트웨이 포함 패킷 이동
```
+-----------------------------------------------------------------------------------+
| AWS Cloud (ap-northeast-2 : 서울 리전)                                              |
|                                                                                   |
|  [ VPC: 10.0.0.0/16 ] (가상 네트워크 )                                              |
|                                                                                   |
|   +---------------------------------------+ +----------------------------------+  |
|   | Public Subnet (10.0.1.0/24)           | | Private Subnet (10.0.101.0/24)   |  |
|   | (외부 공개 구역)                          | | (내부 보안 구역)                    |  |
|   |                                       | |                                  |  |
|   |  [ ALB / Bastion ]                    | |  [ EKS Worker Node / DB ]        |  |
|   +---------------------------------------+ +----------------------------------+  |
|                       |                                      |                    |
|                       | (직접 연결)                            | (NAT 통해 출구만 연결) |
|                       v                                      v                    |
|             [ Internet Gateway ]                    [ NAT Gateway ]               |
|                      |                                       |                    |
+----------------------+---------------------------------------+--------------------+
                       |                                       |
                       +------------------[ 인터넷  ]------------+
```


# 테라폼을 이용한 Custom VPC 구성, company-vpc
## VPC 구성
- ~/tf-step3/vpc.tf 생성
    - 작성
    - terraform init
    - terraform plan
    - terraform apply

## 서브넷 구성 (public)
- 작성
```
terraform apply
---
..
---
terraform state list
---
aws_subnet.public
aws_vpc.DE-AI-25-company
```

## Internet Gateway 
- 작성
- 생성
- 확인

## Route Table
- Route Table 생성

## Route Table 연결
- subnet과 igw를 연결

## 실습
### 목표
    - basic에서 작성한 ec2 lac 코드를 가져와서, vpc, 서브넷 포지션을 vpc.tf로 만들어진 내용으로 연결
    - 테라폼으로 Custom VPC 사용하는 EC2 구성
    - public subnet에 EC2 배치
    - Security group 회사 VPC 맞게 수정(22, 80)
    - EIP
    - 구성 완료 => SSH 접속 확인

### 구성도
```
            Internet
                │
            Internet Gateway
                │
      ┌─────────────────────────┐
      │      Company VPC        │
      │     10.0.0.0/16         │
      │                         │
      │  Public Subnet          │
      │   10.0.1.0/24           │
      │        │                │
      │     EC2 + EIP           │
      └─────────────────────────┘
```
### 작업
- VPC 교체 -> subnet 교체 -> 사용하느곳 모두 교체
- basic 코드 붙여넣기 -> main.tf, variable.tf, provider.tf, outputs.tf
- main.tf 에서 vpc, subnet 코드 삭제
- terraform plan > error > 수정위치가 나옴
```
     9:   vpc_id = data.aws_vpc.default.id => aws_vpc.DE-AI-25-company.id
     72:  subnet_id = data.aws_subnets.default.ids[0] => aws_subnet.public.id
```
- 5. Elastic IP 생성 선언 주석 풀어줌
- outputs.tf에서 EIP의 퍼블릭 IP 출력로 표기
- terraform apply
- terraform graph 
    - 관계도 확인
    ```
        digraph G {
            rankdir = "RL";
            node [shape = rect, fontname = "sans-serif"];
            "data.aws_ami.amazon_linux" [label="data.aws_ami.amazon_linux"];
            "aws_eip.DE-AI-25-IaC-TF-EIP" [label="aws_eip.DE-AI-25-IaC-TF-EIP"];
            "aws_instance.DE-AI-25-IaC-TF" [label="aws_instance.DE-AI-25-IaC-TF"];
            ...
    ```


# 내일(26.7.28) 목표시스템
- private 서브넷 구성
- 3-tier 구성
- NAT Gateway 배치
```
                    Internet
                        │
                Internet Gateway
                        │
                Public Route Table
                        │
      ┌─────────────────┴─────────────────┐
      │                                   │
 Public Subnet (10.0.1.0/24)        Private Subnet (10.0.2.0/24)
      │                                   │
      │                                   │
 ┌────────────┐                    ┌────────────┐
 │ Web EC2    │                    │ DB EC2     │
 │ nginx      │                    │ mysql      │
 └────────────┘                    └────────────┘
                                          │
                                    ┌────────────┐
                                    │ WAS EC2    │
                                    │ FastAPI    │
                                    └────────────┘
```

```
terraform state list
===
data.aws_ami.get_amazon_linux
aws_eip.de-ai-22-IaC-EIP
aws_instance.de-ai-22-IaC-EC2
aws_internet_gateway.company
aws_route_table.public
aws_route_table_association.public
aws_security_group.de-ai-22-IaC-sg
aws_subnet.public
aws_vpc.de-ai-22-company
===
```


### 최종 테라폼 리소스 구성표

| 구 분 | 테라폼 리소스 이름 | 역할 및 바인딩 관계 |
| :--- | :--- | :--- |
| **Data** | `data.aws_ami.get_amazon_linux` | 최신 Amazon Linux 2023 AMI ID 동적 조회 |
| **VPC** | `aws_vpc.de-ai-22-company` | 전용 독자망 네트워크 공간 (`10.0.0.0/16`) |
| **Subnet** | `aws_subnet.public` | VPC 내부의 퍼블릭 구역 (`10.0.1.0/24`) |
| **IGW** | `aws_internet_gateway.company` | VPC 외부 인터넷 출입용 대문 |
| **RT** | `aws_route_table.public` | 외부 트래픽(`0.0.0.0/0`)을 IGW로 전달하는 이정표 |
| **RT Assoc** | `aws_route_table_association.public` | 라우팅 테이블과 퍼블릭 서브넷 바인딩 |
| **SG** | `aws_security_group.de-ai-22-IaC-sg` | VPC 내부 전용 방화벽 (22/SSH, 80/HTTP 허용) |
| **EC2** | `aws_instance.de-ai-22-IaC-EC2` | 퍼블릭 서브넷 및 보안그룹에 배치된 웹 서버 |
| **EIP** | `aws_eip.de-ai-22-IaC-EIP` | EC2에 할당되는 고정 퍼블릭 IP (IGW 의존성 설정) |

```
terraform graph

digraph G {
  rankdir = "RL";
  node [shape = rect, fontname = "sans-serif"];
  "data.aws_ami.get_amazon_linux" [label="data.aws_ami.get_amazon_linux"];
  "aws_eip.de-ai-22-IaC-EIP" [label="aws_eip.de-ai-22-IaC-EIP"];
  "aws_instance.de-ai-22-IaC-EC2" [label="aws_instance.de-ai-22-IaC-EC2"];
  "aws_internet_gateway.company" [label="aws_internet_gateway.company"];
  "aws_route_table.public" [label="aws_route_table.public"];
  "aws_route_table_association.public" [label="aws_route_table_association.public"];
  "aws_security_group.de-ai-22-IaC-sg" [label="aws_security_group.de-ai-22-IaC-sg"];
  "aws_subnet.public" [label="aws_subnet.public"];
  "aws_vpc.de-ai-22-company" [label="aws_vpc.de-ai-22-company"];
  "aws_eip.de-ai-22-IaC-EIP" -> "aws_instance.de-ai-22-IaC-EC2";
  "aws_eip.de-ai-22-IaC-EIP" -> "aws_internet_gateway.company";
  "aws_instance.de-ai-22-IaC-EC2" -> "data.aws_ami.get_amazon_linux";
  "aws_instance.de-ai-22-IaC-EC2" -> "aws_security_group.de-ai-22-IaC-sg";
  "aws_instance.de-ai-22-IaC-EC2" -> "aws_subnet.public";
  "aws_internet_gateway.company" -> "aws_vpc.de-ai-22-company";
  "aws_route_table.public" -> "aws_internet_gateway.company";
  "aws_route_table_association.public" -> "aws_route_table.public";
  "aws_route_table_association.public" -> "aws_subnet.public";
  "aws_security_group.de-ai-22-IaC-sg" -> "aws_vpc.de-ai-22-company";
  "aws_subnet.public" -> "aws_vpc.de-ai-22-company";
}
```