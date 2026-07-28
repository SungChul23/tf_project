#개요
- 테라폼 hands-on


### 최종적 테라폼 리소스 구성표

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


