# Terraform 기초

## 개요

- 기본 구성
- EC2 구성
- 문법

---

## 작업

### 기본 구성

**기본 파일 생성** (작업 디렉토리: `~/basic`)

```
provider.tf
main.tf
variables.tf
outputs.tf
terraform.tfvars
.gitignore
```

- `provider.tf` 작성

---

## 인프라 구성

### step1 : 테라폼 초기화 (init)

```bash
terraform init
```

**성공 후 결과물**
- `.terraform/` : 공급자 플러그인, 바이너리, 모듈 캐시, 정보 등 저장
- `.terraform.lock.hcl` : 프로바이더 모듈의 정확한 버전, 해시값 잠금 → 안정성 확보, 자동 생성 및 체킹 파일

---

### step2 : 문법 검사(체킹) (validate)

```bash
terraform validate
```

```
Success! The configuration is valid.
```

---

### step3 : 실행 계획 확인 (플래닝, 시뮬레이션) (plan)

```bash
terraform plan
```

**현재 내용 없음**
```
No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration and found no differences, so no
changes are needed.
```

**실제로는**
- provider → resource(보안그룹, VPC, EIP, ...) 생성 계획을 미리 보여줌

---

### step4 : 적용(실제 생성) (apply)

```bash
terraform apply
```

**현재는 인프라 구성 내용 없음**
```
No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration and found no differences, so no
changes are needed.

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

**실제 적용 시**
- EC2의 경우 1~2분, 쿠버네티스 등은 10분 이내 등 리소스 종류에 따라 시간 소요

---

### step5 : 인프라 삭제 (destroy)

```bash
terraform destroy
```

**삭제된 것 없음 (만든 것이 없어서)**
```
No changes. No objects need to be destroyed.

Either you have not created any objects yet or the existing objects were already deleted outside of
Terraform.

Destroy complete! Resources: 0 destroyed.
```


## EC2 구성
### 최종 형태

```

Internet
     │
     │
Elastic IP          <-- 리소스 생성
     │
┌──────────────┐
│     EC2      │
│ AmazonLinux2 │    <-- 아마존 리눅스 사용 /ec2-user
└──────────────┘
     │
Security Group      <-- 보안그룹 전용 생성 (인바(22)/아웃바(all))
     │
VPC(Default)        <-- 기본 사용

----
pem 파일, 스토리지, 리전, 이름 . . . 

```

### 세부 구성
- *.tf 파일은 1개만 구성해도 ok, n개 구성해도 ok
- n개의 tf로 구성이 되도, 생성 순서에 따라 구동 흐름이 자동 조정됨 (plan,graph등 명령을 통해 확인 가능)

- variables.tf
    - 리전, 인스턴스 타입, pem 이름 설정
    - provider.tf 변수 사용
    - 문법 검사
        ```
        terraform validate
        ---
        Success! The configuration is valid.
            
        ```
- provider.tf
     - 구성에 필요한 패키지 등 사용 버전 + 리전

- main.tf
     - 통합적으로 구성 (vpc -> 서브넷 -> 보안그룹(동적생성도 가능) -> os 이미지 조회/선택(AmazonLinux2) -> EC2 생성 선언 -> 탄력적 IP 생성 후 연결)
     - 클라우드 내부에 본인만 사용하는 사설네트워크(VPC 관련 전체 리소스) 만 제외하고 전체 구성을 동적으로 생성
     - VPC는 리전별로 기본이 하나씩 구성되어 있다 (없으면 생성 가능)
          - 현재는 서울리전의 기본 vpc 서브넷 4개, 라우팅 테이블 1 개, 인터넷 게이트웨이 1개 로 구성되어 있음 -> 어떤 서브넷을 사용하던 EC2는 외부에서 접속 가능한 구조임