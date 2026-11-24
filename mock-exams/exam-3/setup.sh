#!/usr/bin/env bash
# Prepares CKAD mock exam 3. Run before starting the timer.
set -euo pipefail

for ns in c3-app c3-helm c3-prod c3-logs c3-quota c3-net c3-web; do
  kubectl create ns "$ns" --dry-run=client -o yaml | kubectl apply -f -
done
kubectl label ns c3-web tier=web --overwrite

mkdir -p /tmp/c3 /tmp/c3-kust/base
cat > /tmp/c3/Dockerfile <<'EOF'
FROM busybox:1.36
COPY tool.sh /usr/local/bin/tool.sh
ENTRYPOINT ["/usr/local/bin/tool"]
EOF
printf '#!/bin/sh\necho "tool finished"\n' > /tmp/c3/tool.sh
cat > /tmp/c3/manifests.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: {name: a}
spec: {selector: {matchLabels: {app: a}}, template: {metadata: {labels: {app: a}}, spec: {containers: [{name: a, image: nginx}]}}}
---
apiVersion: flowcontrol.apiserver.k8s.io/v1beta2
kind: FlowSchema
metadata: {name: b}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: c}
spec: {podSelector: {}}
---
apiVersion: discovery.k8s.io/v1beta1
kind: EndpointSlice
metadata: {name: d}
---
apiVersion: batch/v1
kind: CronJob
metadata: {name: e}
---
apiVersion: storage.k8s.io/v1beta1
kind: CSIStorageCapacity
metadata: {name: f}
EOF
cat > /tmp/c3-kust/base/kustomization.yaml <<'EOF'
resources: [deployment.yaml]
EOF
cat > /tmp/c3-kust/base/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: {name: api}
spec:
  replicas: 1
  selector: {matchLabels: {app: api}}
  template:
    metadata: {labels: {app: api}}
    spec:
      containers: [{name: api, image: "nginx:1.27"}]
EOF

kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: {name: migrator, namespace: c3-app}
spec:
  replicas: 2
  selector: {matchLabels: {app: migrator}}
  template:
    metadata: {labels: {app: migrator}}
    spec:
      containers: [{name: m, image: "busybox:1.36", command: ["sleep", "infinity"]}]
---
# Task 8
apiVersion: v1
kind: Pod
metadata: {name: gateway, namespace: c3-logs}
spec:
  containers:
    - name: proxy
      image: busybox:1.36
      command: ["sh", "-c", "i=0; while true; do i=$((i+1)); s=200; [ $((i % 4)) -eq 0 ] && s=500; echo \"req=$i path=/api status=$s\"; sleep 1; done"]
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "while true; do echo 'app status=500 internal (should not be counted)'; sleep 2; done"]
---
# Task 9
apiVersion: apps/v1
kind: Deployment
metadata: {name: cache, namespace: c3-app}
spec:
  replicas: 1
  selector: {matchLabels: {app: cache}}
  template:
    metadata: {labels: {app: cache}}
    spec:
      containers:
        - name: redis
          image: redis:7
          args: ["--maxmemory", "64mb"]
          resources: {limits: {memory: 8Mi}}
---
# Task 13
apiVersion: v1
kind: ServiceAccount
metadata: {name: deployer, namespace: c3-app}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {name: deployer, namespace: c3-app}
rules:
  - apiGroups: [apps]
    resources: [deployments]
    verbs: [get, list, create, update, patch]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: deployer, namespace: c3-app}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: Role, name: deployer}
subjects: [{kind: ServiceAccount, name: deployer, namespace: c3-app}]
---
# Task 14
apiVersion: apps/v1
kind: Deployment
metadata: {name: web, namespace: c3-app}
spec:
  selector: {matchLabels: {app: web}}
  template:
    metadata: {labels: {app: web}}
    spec:
      containers: [{name: web, image: "nginx:1.27"}]
---
# Task 15–17
apiVersion: apps/v1
kind: Deployment
metadata: {name: api, namespace: c3-net}
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
metadata: {name: api, namespace: c3-net}
spec: {selector: {app: api}, ports: [{port: 8080}]}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: www, namespace: c3-net}
spec:
  selector: {matchLabels: {app: www}}
  template:
    metadata: {labels: {app: www}}
    spec:
      containers: [{name: www, image: "nginx:1.27"}]
---
apiVersion: v1
kind: Service
metadata: {name: www, namespace: c3-net}
spec: {selector: {app: www}, ports: [{port: 80}]}
---
apiVersion: v1
kind: Pod
metadata: {name: frontend, namespace: c3-web, labels: {app: frontend}}
spec:
  containers: [{name: c, image: "busybox:1.36", command: ["sleep", "infinity"]}]
---
apiVersion: v1
kind: Pod
metadata: {name: frontend, namespace: c3-app, labels: {app: frontend}}
spec:
  containers: [{name: c, image: "busybox:1.36", command: ["sleep", "infinity"]}]
EOF

echo "✅ Mock exam 3 ready. Start the timer: 120 minutes."
