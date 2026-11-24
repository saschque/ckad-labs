#!/usr/bin/env bash
# Prepares CKAD mock exam 1. Run before starting the timer.
set -euo pipefail

for ns in c1-app c1-helm c1-debug c1-quota c1-net; do
  kubectl create ns "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

# Task 1: app sources
mkdir -p /tmp/c1
cat > /tmp/c1/Dockerfile <<'EOF'
FROM busybox:1.36
WORKDIR /www
COPY index.html .
EXPOSE 8080
CMD ["httpd", "-f", "-p", "8080", "-h", "/www"]
EOF
echo '<h1>c1 app</h1>' > /tmp/c1/index.html

# Task 7: deprecated manifests
cat > /tmp/c1/old-manifests.yaml <<'EOF'
apiVersion: policy/v1beta1
kind: PodDisruptionBudget
metadata: {name: api-pdb, namespace: c1-app}
spec:
  minAvailable: 1
  selector: {matchLabels: {app: api}}
---
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata: {name: legacy, namespace: c1-app}
spec:
  rules:
    - host: legacy.c1.lab
      http:
        paths:
          - path: /
            backend: {serviceName: api, servicePort: 80}
EOF

kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: {name: api, namespace: c1-app}
spec:
  replicas: 3
  selector: {matchLabels: {app: api}}
  template:
    metadata: {labels: {app: api}}
    spec:
      containers: [{name: nginx, image: "nginx:1.26"}]
---
apiVersion: v1
kind: Service
metadata: {name: api, namespace: c1-app}
spec: {selector: {app: api}, ports: [{port: 80}]}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: shop-v1, namespace: c1-app}
spec:
  replicas: 3
  selector: {matchLabels: {app: shop, version: v1}}
  template:
    metadata: {labels: {app: shop, version: v1}}
    spec:
      containers: [{name: nginx, image: "nginx:1.26"}]
---
apiVersion: v1
kind: Service
metadata: {name: shop, namespace: c1-app}
spec: {selector: {app: shop}, ports: [{port: 80}]}
---
apiVersion: v1
kind: ConfigMap
metadata: {name: c1-settings, namespace: c1-app}
data: {MODE: production, LEVEL: "3"}
---
apiVersion: v1
kind: Secret
metadata: {name: c1-secret, namespace: c1-app}
stringData: {token: "s3cr3t-t0ken", other: "x"}
---
# Task 9
apiVersion: v1
kind: Pod
metadata: {name: worker, namespace: c1-debug}
spec:
  containers:
    - name: worker
      image: busybox:1.36
      command: ["sh", "-c", "echo 'starting worker'; [ -n \"$QUEUE_URL\" ] || { echo 'ERROR: QUEUE_URL is not set' >&2; exit 1; }; sleep 3600"]
---
# Task 13
apiVersion: v1
kind: ResourceQuota
metadata: {name: quota, namespace: c1-quota}
spec:
  hard: {requests.cpu: 500m, requests.memory: 256Mi, limits.cpu: "1", limits.memory: 512Mi}
---
# Task 14
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata: {name: databases.data.ckad.io}
spec:
  group: data.ckad.io
  scope: Namespaced
  names: {kind: Database, plural: databases, singular: database, shortNames: [db]}
  versions:
    - name: v1alpha1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              required: [engine, storageGB]
              properties:
                engine: {type: string, enum: [postgres, mysql], description: "Database engine"}
                storageGB: {type: integer, minimum: 1, description: "Storage size in GB"}
---
# Task 15 / 16
apiVersion: apps/v1
kind: Deployment
metadata: {name: db, namespace: c1-net}
spec:
  selector: {matchLabels: {app: db}}
  template:
    metadata: {labels: {app: db}}
    spec:
      containers: [{name: db, image: "registry.k8s.io/pause:3.10"}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: catalog, namespace: c1-net}
spec:
  replicas: 2
  selector: {matchLabels: {app: catalog}}
  template:
    metadata: {labels: {app: catalog}}
    spec:
      containers:
        - name: catalog
          image: registry.k8s.io/e2e-test-images/agnhost:2.53
          args: ["netexec", "--http-port=9000"]
          ports: [{containerPort: 9000}]
---
apiVersion: v1
kind: Service
metadata: {name: catalog, namespace: c1-net}
spec:
  selector: {app: catalogue}
  ports: [{port: 80, targetPort: 8080}]
---
apiVersion: v1
kind: Pod
metadata: {name: client, namespace: c1-net, labels: {role: client}}
spec:
  containers: [{name: c, image: "busybox:1.36", command: ["sleep", "infinity"]}]
EOF

echo "✅ Mock exam 1 ready. Start the timer: 120 minutes."
