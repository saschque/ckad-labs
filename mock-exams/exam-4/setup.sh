#!/usr/bin/env bash
# Prepares CKAD mock exam 4. Run before starting the timer.
set -euo pipefail

for ns in c4-app c4-helm c4-broken c4-net c4-monitoring; do
  kubectl create ns "$ns" --dry-run=client -o yaml | kubectl apply -f -
done
kubectl label ns c4-monitoring purpose=monitoring --overwrite

mkdir -p /tmp/c4
printf 'admin' > /tmp/c4/username
printf 'c4-Pa55' > /tmp/c4/password

kubectl apply -f - <<'EOF'
# Task 4
apiVersion: apps/v1
kind: Deployment
metadata: {name: web-stable, namespace: c4-app}
spec:
  replicas: 3
  selector: {matchLabels: {app: web, track: stable}}
  template:
    metadata: {labels: {app: web, track: stable}}
    spec:
      containers: [{name: nginx, image: "nginx:1.26"}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: web-canary, namespace: c4-app}
spec:
  replicas: 1
  selector: {matchLabels: {app: web, track: canary}}
  template:
    metadata: {labels: {app: web, track: canary}}
    spec:
      containers: [{name: nginx, image: "nginx:1.27"}]
---
apiVersion: v1
kind: Service
metadata: {name: web, namespace: c4-app}
spec: {selector: {app: web}, ports: [{port: 80}]}
---
# Task 5, 17
apiVersion: apps/v1
kind: Deployment
metadata: {name: api, namespace: c4-app}
spec:
  replicas: 2
  selector: {matchLabels: {app: api}}
  template:
    metadata: {labels: {app: api}}
    spec:
      containers: [{name: nginx, image: "nginx:1.27"}]
---
apiVersion: v1
kind: Service
metadata: {name: api, namespace: c4-app}
spec: {selector: {app: api}, ports: [{port: 80}]}
---
# Task 8
apiVersion: v1
kind: Pod
metadata: {name: ok-pod, namespace: c4-broken}
spec:
  containers: [{name: c, image: "registry.k8s.io/pause:3.10"}]
---
apiVersion: v1
kind: Pod
metadata: {name: pull-fail, namespace: c4-broken}
spec:
  containers: [{name: c, image: "registry.k8s.io/pause:0.0.0-nope"}]
---
apiVersion: v1
kind: Pod
metadata: {name: crash-loop, namespace: c4-broken}
spec:
  containers: [{name: c, image: "busybox:1.36", command: ["sh", "-c", "exit 1"]}]
---
apiVersion: v1
kind: Pod
metadata: {name: unschedulable, namespace: c4-broken}
spec:
  nodeSelector: {disk: nvme}
  containers: [{name: c, image: "registry.k8s.io/pause:3.10"}]
---
# Task 9
apiVersion: v1
kind: ConfigMap
metadata: {name: locked-config, namespace: c4-app}
data: {app.conf: "feature_x=enabled\nlimit=42"}
---
apiVersion: v1
kind: Pod
metadata: {name: app-locked, namespace: c4-app}
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "echo 'refusing to start: license missing'; exit 1"]
      volumeMounts: [{name: cfg, mountPath: /config}]
  volumes: [{name: cfg, configMap: {name: locked-config}}]
---
# Task 13
apiVersion: apps/v1
kind: Deployment
metadata: {name: critical, namespace: c4-app}
spec:
  selector: {matchLabels: {app: critical}}
  template:
    metadata: {labels: {app: critical}}
    spec:
      containers:
        - {name: c, image: "nginx:1.27", resources: {requests: {cpu: 50m, memory: 32Mi}}}
---
# Task 14
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata: {name: features.flags.ckad.io}
spec:
  group: flags.ckad.io
  scope: Namespaced
  names: {kind: Feature, plural: features, singular: feature, shortNames: [ff]}
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
              required: [enabled]
              properties:
                enabled: {type: boolean, description: "Whether the feature is active"}
                rollout:
                  type: object
                  description: "Gradual rollout settings"
                  properties:
                    percentage: {type: integer, minimum: 0, maximum: 100, description: "Share of users that get the feature"}
---
# Task 15 / 16
apiVersion: apps/v1
kind: Deployment
metadata: {name: inventory, namespace: c4-net}
spec:
  replicas: 2
  selector: {matchLabels: {app: inventory}}
  template:
    metadata: {labels: {app: inventory}}
    spec:
      containers:
        - name: inventory
          image: registry.k8s.io/e2e-test-images/agnhost:2.53
          args: ["netexec", "--http-port=8080"]
          ports: [{name: web, containerPort: 8080}]
---
apiVersion: v1
kind: Service
metadata: {name: inventory, namespace: c4-net}
spec:
  selector: {app: inventory}
  ports: [{port: 80, targetPort: http}]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: inventory-lock, namespace: c4-net}
spec:
  podSelector: {matchLabels: {app: inventory}}
  policyTypes: [Ingress]
---
apiVersion: v1
kind: Pod
metadata: {name: tester, namespace: c4-net, labels: {role: tester}}
spec:
  containers: [{name: c, image: "busybox:1.36", command: ["sleep", "infinity"]}]
EOF

echo "✅ Mock exam 4 ready. Start the timer: 120 minutes."
