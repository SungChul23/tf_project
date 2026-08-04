# IngressClassParams — ALB의 세부 동작(인터넷 공개 여부 등)을 정의
apiVersion: eks.amazonaws.com/v1
kind: IngressClassParams
metadata:
  name: alb
spec:
  scheme: internet-facing
---
# IngressClass — "alb"라는 이름의 클래스를 쿠버네티스 기본 Ingress 컨트롤러로 등록
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: alb
  annotations:
    ingressclass.kubernetes.io/is-default-class: "true"
spec:
  controller: eks.amazonaws.com/alb         # AWS EKS의 ALB 컨트롤러가 ingress를 담당
  parameters:                               # 리소스 상세정보 연결
    apiGroup: eks.amazonaws.com             # 리소스 EKS API 그룹
    kind: IngressClassParams                
    name: alb
---
# Namespace — 이 프로젝트의 모든 리소스를 담을 논리적 공간
apiVersion: v1
kind: Namespace
metadata:
  name: ${APP_NAMESPACE}
---
# Deployment(WAS) — 백엔드 API 서버 Pod를 2개 띄우고 관리
apiVersion: apps/v1             # Deployment 기능을 제공하는 API 버전
kind: Deployment                # 파드의 생성, 복구, 개수 유지 담당
metadata:                       # Deployment 기본 정보
  name: was                     # Deployment 이름
  namespace: ${APP_NAMESPACE}   # Deployment 리소스 객체가 생성되는 네임스페이스
spec:                           # Deployment 실제 설정
  replicas: 2                   # was pod은 최소 2개를 실행한다
  selector:                     # pod 선택 조건
    matchLabels:                # Label 기준으로 파드 선택 -> 파드 web, was
      app: was                  # app-was 라는 형태로 label 을 가진 파드를 관리
  template:                     # Deployment가 관리하는 파드의 설계도
    metadata:                   # 기본 정보
      labels:                   # Label
        app: was                # app-was, Deployment 파드 생성시 파드를 찾는 조건
        tier: backend           # 실제 실행 정보
    spec:
      # 같은 앱의 Pod들을 서로 다른 AZ에 고르게 분산 배치 (한쪽 AZ 장애 대비)
      topologySpreadConstraints: 
        - maxSkew: 1            # AZ 별 파드 개수는 최대 1개
          minDomains: 2         # 최소 2개, 가용영역에서 분산
          topologyKey: topology.kubernetes.io/zone # 분산 기준을 AZ로 지정
          whenUnsatisfiable: DoNotSchedule         # 분산 조건을 만족하지 않으면 배치 X
          labelSelector:        # 분산 규칙을 따르는 파드는
            matchLabels:        # Label
              app: was          # app-was로 이러우진 파드만 적용
      containers:                   # 파드 내부 컨테이너 설정
        - name: was                 # 컨테이너 명
          image: ${WAS_IMAGE}       # ECR 주소
          imagePullPolicy: Always   # 파드 시작시 실제로 이미지가 존재하는지
          ports:
            - name: http
              containerPort: 8000
          # RDS 접속 정보 등 민감값을 Secret에서 통째로 환경변수로 주입
          envFrom:
            - secretRef:            # 쿠퍼네티스 secreat 참조
                name: rds-secret    # RDS 접속 정보 참조
          # Pod가 쓸 CPU/메모리 최소 보장치와 최대 허용치
          resources:                # 컨테이너 구동시
            requests:               
              cpu: 100m             # CPU 10퍼센트
              memory: 128Mi         # 128 mb
            limits:
              cpu: 500m
              memory: 512Mi
          # 트래픽 받을 준비가 됐는지 체크 (실패 시 Service에서 제외)
          readinessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 5  # 컨테이너 시작 5초 후 검사 진행
            periodSeconds: 10       # 10초 간격으로 검사
            timeoutSeconds: 3       # 3초 안에 응답 없으면 실패
            failureThreshold: 3     # 총 3번의 기회
          # 살아있는지 체크 (실패 시 컨테이너 재시작)
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 15 
            periodSeconds: 20
            timeoutSeconds: 3
            failureThreshold: 3
---
# Service(WAS) — WAS Pod들의 대표 접속 주소 (클러스터 내부 전용)
apiVersion: v1
kind: Service                       # 여러 was pod에 고정된(단일) 접근 주소 제공
metadata:                           # 기본 정보
  name: was-service                  
  namespace: ${APP_NAMESPACE}
spec:
  selector:                         # 파드 선택 조건
    app: was                        # app - was 라벨을 가진 파드만 대상
  ports:
    - name: http
      port: 8000
      targetPort: http
  type: ClusterIP                   # 클러스터 내부에서만 접근 가능한 service
---
# PodDisruptionBudget(WAS) — 노드 교체/롤링 업데이트 중에도 최소 1개는 항상 살아있게 보장
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: was-pdb
  namespace: ${APP_NAMESPACE}
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: was
---
# HorizontalPodAutoscaler(WAS) — CPU 사용률 60% 넘으면 Pod를 최대 6개까지 자동 확장
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler       # CPU/MEM 기준으로 자동 확장 (노드)
metadata:                           # 메타데이터 
  name: was-hpa                     # HPA 이름
  namespace: ${APP_NAMESPACE}
spec:
  scaleTargetRef:                   # sacle 할 대상 참조
    apiVersion: apps/v1             
    kind: Deployment                # sacle 대상은 Deployment
    name: was                       # was 파드만 담당
  minReplicas: 2                            # 최소 2개 유지
  maxReplicas: 6                            # 최대 6개 까지
  behavior:
    scaleDown:                          # 스케일 인
      stabilizationWindowSeconds: 300   # 30초 정도 트래픽이 안정되면     
  metrics:      
    - type: Resource
      resource:
        name: cpu                       # 메트릭 대상 : CPU
        target:
          type: Utilization             # request.cpu 대비 사용률
          averageUtilization: 60        # 전체 was-pod 기준 60퍼센트
---
# Deployment(Web) — 프론트엔드 Pod를 2개 띄우고 관리
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: ${APP_NAMESPACE}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
        tier: frontend
    spec:
      # 같은 앱의 Pod들을 서로 다른 AZ에 고르게 분산 배치
      topologySpreadConstraints:
        - maxSkew: 1
          minDomains: 2
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: web
      containers:
        - name: web
          image: ${WEB_IMAGE}
          imagePullPolicy: Always
          ports:
            - name: http
              containerPort: 80
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 300m
              memory: 256Mi
          readinessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 3
            periodSeconds: 10
            timeoutSeconds: 3
            failureThreshold: 3
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 10
            periodSeconds: 20
            timeoutSeconds: 3
            failureThreshold: 3
---
# Service(Web) — Web Pod들의 대표 접속 주소 (클러스터 내부 전용, Ingress가 이걸 가리킴)
apiVersion: v1
kind: Service
metadata:
  name: web-service
  namespace: ${APP_NAMESPACE}
spec:
  selector:
    app: web
  ports:
    - name: http
      port: 80
      targetPort: http
  type: ClusterIP
---
# PodDisruptionBudget(Web) — Web도 동일하게 최소 1개는 항상 살아있게 보장
apiVersion: policy/v1
kind: PodDisruptionBudget           # 중단 상황에서도 최소 가용 개수 보장
metadata:
  name: web-pdb
  namespace: ${APP_NAMESPACE}
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: web
---
# HorizontalPodAutoscaler(Web) — CPU 사용률 60% 넘으면 Pod를 최대 6개까지 자동 확장
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler       # CPU/MEM 기준으로 자동 확장 (노드)
metadata:
  name: web-hpa
  namespace: ${APP_NAMESPACE}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web
  minReplicas: 2
  maxReplicas: 6
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 60
---
# Ingress — 외부 트래픽의 진입점. "/" 경로로 들어오는 요청을 web-service로 전달
apiVersion: networking.k8s.io/v1
kind: Ingress                       # 외부 요청의 진입 경로와 전달 규칙 정의(라우팅 규칙)
metadata:
  name: public-alb
  namespace: ${APP_NAMESPACE}
spec:
  ingressClassName: alb             # alb 관련 내용 
  rules:
    - http:                         # http 요청
        paths:                      # 경로 지정
          - path: /                 # 루트 경로
            pathType: Prefix        # /로 시작하는 모든 하위 경로 포함
            backend:                # 요청을 전달할 백엔드 설정
              service:              # 서비스 지정
                name: web-service   # "web-service" 라는 이름으로 보낸다
                port:   
                  number: 80        # 80 포트
