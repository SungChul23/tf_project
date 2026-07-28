# 목표
- 회사 전용으로 클라우드내 네트워크 구축 -> VPC
- 현재 EC2는 defaults VPC 사용 -> 전용 VPC로 직접 생성하여 적용

- [v] VPC만 구축 (가장 먼저 실행할 작업) 
    -> [v] EC2에 커스텀 VPC 연결 하여 인프라구성 -> WEB,WAS,DB로 확장
    -> web(public subnet), was/db(private subnet) 확장 + NAT G/W, SSH Manage, IAM Role
    -> 소스코드, 쿠버네티스, CI/CD
    -> 대시보드 (그라파타, 프로메테우스 . . .)

# 구성
    - AWS
        - VPC
        - CIDR
        - Public/Private Subnet
        - Internet GW
        - NAT G/W
        - Route Table/Route Table Assoication

# VPC
## 정의
- AWS 안에 내가 "직접 만드는 사설 네트워크"
- AWS 안에 나만 사용하는 독립된 네트워크 공간

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

    - NAT Gateway :
        - Private Subnet을 위해서 구성
            - 외부에서 Private Subnet으로 접근 x
            - s/w 설치를 해야하는 경우, 소스코드 획득 등 내부에서 외부의 자원을 가져올 필요가 있음(pull)
            - 이를 위해서 NAT gateway 가 필요함

# 구성원 1
## VPC
- Default VPC
    - 리전별 n개 구성 (통상 자동으로 만들어져 있음)
    - EC2 구성시 바로 사용 가능(퍼블릭 기본 세팅)
    - 학습, 테스트시 유용
    - 나만의 VPC x
- [v] Custom VPC
    - 하위 구성원들 직접 구성(설계)
    - 운영환경등 활용
    - 나만의 VPC o

## CIDR
    - VPC 구성시 IP 즈소 범위 지정
    ```
        #설정
        10.0.0.0/16 (총 32 비트로 이루어져있으며 /16이라 앞에서 두번째 까지는 고정 즉, 뒤에 2자리만 사용가능)
        10.0.0.10 -> O
        10.0.1.10 -> O
        10.0.255.254 -> O

        10.1.0.10 -> X 
    ```

## 서브넷
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
        ```
            Internet <-> IGW <-> Route Table <-> Public Subnet <-> EC2                    
        ```
    - 프라이빗 서브넷
        ```
            Internet                       X  Route Table <-> Public Subnet <-> EC2
            Internet  <-(pull) NAT Gateway <-> Route Table <-> Public Subnet <-> EC2
        ```

## 게이트웨이
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