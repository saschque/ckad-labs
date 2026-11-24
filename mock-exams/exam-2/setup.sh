#!/usr/bin/env bash
# Prepares CKAD mock exam 2. Run before starting the timer.
set -euo pipefail

for ns in c2-app c2-staging c2-load c2-secure c2-limits c2-net; do
  kubectl create ns "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

mkdir -p /tmp/c2 /tmp/c2-kust/base
cat > /tmp/c2/Dockerfile <<'EOF'
FROM alpine:3.20
RUN mkdir /app && echo 'echo "api running as $(id -u)"; sleep 3600' > /app/run.sh
CMD ["sh", "/app/run.sh"]
EOF
printf 'host=db.c2.lab\nuser=app\npassword=c2pass\n' > /tmp/c2/db.properties
cat > /tmp/c2-kust/base/kustomization.yaml <<'EOF'
resources: [deployment.yaml]
EOF
cat > /tmp/c2-kust/base/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: {name: web}
spec:
  selector: {matchLabels: {app: web}}
  template:
    metadata: {labels: {app: web}}
    spec:
      containers: [{name: web, image: "nginx:1.27"}]
EOF

# Task 5: revisions 1 (ok), 2 (ok), 3 (broken), 4 (broken)
kubectl -n c2-app create deploy catalog --image=nginx:1.25 --replicas=2 --dry-run=client -o yaml | kubectl apply -f -
kubectl -n c2-app rollout status deploy/catalog --timeout=120s
kubectl -n c2-app set image deploy/catalog nginx=nginx:1.26 && kubectl -n c2-app rollout status deploy/catalog --timeout=120s
kubectl -n c2-app set image deploy/catalog nginx=nginx:1.26-nope
sleep 3
kubectl -n c2-app set image deploy/catalog nginx=nginx:1.27-nope

kubectl apply -f - <<'EOF'
# Task 4
apiVersion: apps/v1
kind: Deployment
metadata: {name: checkout-blue, namespace: c2-app}
spec:
  replicas: 2
  selector: {matchLabels: {app: checkout, color: blue}}
  template:
    metadata: {labels: {app: checkout, color: blue}}
    spec:
      containers: [{name: nginx, image: "nginx:1.26"}]
---
apiVersion: v1
kind: Service
metadata: {name: checkout, namespace: c2-app}
spec:
  selector: {app: checkout, color: blue}
  ports: [{port: 80}]
---
# Task 7
apiVersion: apps/v1
kind: Deployment
metadata: {name: legacy-app, namespace: c2-app}
spec:
  replicas: 1
  selector: {matchLabels: {app: legacy-app}}
  template:
    metadata: {labels: {app: legacy-app}}
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command: ["sh", "-c", "sleep 30; mkdir -p /www; echo ok > /www/healthz; httpd -f -p 8080 -h /www"]
          livenessProbe:
            httpGet: {path: /healthz, port: 8080}
            periodSeconds: 5
            failureThreshold: 3
---
# Task 8
apiVersion: v1
kind: Pod
metadata: {name: small, namespace: c2-load}
spec:
  containers: [{name: c, image: "registry.k8s.io/pause:3.10"}]
---
apiVersion: v1
kind: Pod
metadata: {name: big, namespace: c2-load}
spec:
  containers:
    - {name: c, image: polinux/stress, command: ["stress", "--vm", "1", "--vm-bytes", "100M", "--vm-hang", "0"], resources: {limits: {memory: 200Mi}}}
---
# Task 9
apiVersion: v1
kind: Pod
metadata: {name: minimal, namespace: c2-app}
spec:
  containers: [{name: app, image: "registry.k8s.io/pause:3.10"}]
---
# Task 10
apiVersion: v1
kind: ConfigMap
metadata: {name: c2-flags, namespace: c2-app}
data:
  DARK_MODE: "true"
  BETA: "false"
  rules.json: '{"maxItems": 10}'
---
# Task 14
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata: {name: widgets.toys.ckad.io}
spec:
  group: toys.ckad.io
  scope: Cluster
  names: {kind: Widget, plural: widgets, singular: widget, shortNames: [wdg]}
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                color: {type: string}
---
# Task 15 / 16
apiVersion: apps/v1
kind: Deployment
metadata: {name: api, namespace: c2-net}
spec:
  replicas: 2
  selector: {matchLabels: {app: api}}
  template:
    metadata: {labels: {app: api}}
    spec:
      containers: [{name: api, image: "registry.k8s.io/e2e-test-images/agnhost:2.53", args: ["netexec", "--http-port=8080"]}]
---
apiVersion: v1
kind: Service
metadata: {name: api, namespace: c2-net}
spec: {selector: {app: api}, ports: [{port: 8080}]}
---
apiVersion: v1
kind: Pod
metadata: {name: frontend, namespace: c2-net, labels: {app: frontend}}
spec:
  containers: [{name: c, image: "busybox:1.36", command: ["sleep", "infinity"]}]
EOF

echo "✅ Mock exam 2 ready. Start the timer: 120 minutes."
