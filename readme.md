#개요
- 기본 구성
- EC2 구성
- 문법

# 작업
## 기본구성
- 기본 파일 생성 (작업 dir - basic)
```
provider.tf	어떤 클라우드(AWS 등) 쓸지, 리전 등 기본 설정
main.tf	실제 리소스 정의 (EC2, 보안그룹 등 "뭘 만들지")
variables.tf	재사용할 변수 선언 (값은 안 넣고 "이런 변수 쓸 거야"만 정의)
outputs.tf	실행 후 결과값 출력 (예: 생성된 EC2의 퍼블릭 IP)
---
terraform.tfvars	variables.tf에서 선언한 변수에 실제 값을 넣는 파일
.gitignore	Git에 올리면 안 되는 파일/폴더 제외 목록
```


```
[파일 간 연결 흐름]
variables.tf  (변수 선언: "instance_type이라는 변수를 쓸 거야")
      ↓
terraform.tfvars  (변수에 실제 값 주입: "instance_type = t3.micro")
      ↓
main.tf  (그 변수를 사용해서 실제 리소스 정의)
      ↓
provider.tf  (어느 클라우드에 만들지 설정)
      ↓
terraform apply  (실제 생성)
      ↓
outputs.tf  (결과값 화면에 출력)
```


## EC2 구성