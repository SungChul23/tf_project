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
  controller: eks.amazonaws.com/alb
  parameters:
    apiGroup: eks.amazonaws.com
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
apiVersion: apps/v1
kind: Deployment
metadata:
  name: was
  namespace: ${APP_NAMESPACE}
spec:
  replicas: 2               # was pod은 최소 2개를 실행한다
  selector:
    matchLabels:
      app: was
  template:
    metadata:
      labels:
        app: was
        tier: backend
    spec:
      # 같은 앱의 Pod들을 서로 다른 AZ에 고르게 분산 배치 (한쪽 AZ 장애 대비)
      topologySpreadConstraints:
        - maxSkew: 1
          minDomains: 2
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: was
      containers:
        - name: was
          image: ${WAS_IMAGE}
          imagePullPolicy: Always
          ports:
            - name: http
              containerPort: 8000
          # RDS 접속 정보 등 민감값을 Secret에서 통째로 환경변수로 주입
          envFrom:
            - secretRef:
                name: rds-secret
          # Pod가 쓸 CPU/메모리 최소 보장치와 최대 허용치
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
          # 트래픽 받을 준비가 됐는지 체크 (실패 시 Service에서 제외)
          readinessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 5
            periodSeconds: 10
            timeoutSeconds: 3
            failureThreshold: 3
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
kind: Service
metadata:
  name: was-service
  namespace: ${APP_NAMESPACE}
spec:
  selector:
    app: was
  ports:
    - name: http
      port: 8000
      targetPort: http
  type: ClusterIP
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
kind: HorizontalPodAutoscaler
metadata:
  name: was-hpa
  namespace: ${APP_NAMESPACE}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: was
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
kind: PodDisruptionBudget
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
kind: HorizontalPodAutoscaler
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
kind: Ingress
metadata:
  name: public-alb
  namespace: ${APP_NAMESPACE}
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web-service
                port:
                  number: 80
