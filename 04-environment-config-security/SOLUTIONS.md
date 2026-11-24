# Domain 4 – Solutions

> Only look after your own attempt!

## 4.1 – Discover and use CRDs & operators
```bash
kubectl api-resources --api-group=cert-manager.io
kubectl api-resources --api-group=cert-manager.io -o name
kubectl api-resources | awk '$NF=="Certificate"{print $2}' > /tmp/cert-shortname.txt     # cert
kubectl explain certificate.spec | grep -i required -A3
kubectl explain certificate.spec.issuerRef
```
```yaml
apiVersion: cert-manager.io/v1
kind: Issuer
metadata: {name: selfsigned, namespace: config}
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata: {name: app-cert, namespace: config}
spec:
  secretName: app-cert-tls
  dnsNames: [app.ckad.lab]
  issuerRef: {name: selfsigned, kind: Issuer}
---
apiVersion: v1
kind: Pod
metadata: {name: tls-app, namespace: config}
spec:
  containers:
    - name: c
      image: busybox:1.36
      command: ["sleep", "3600"]
      volumeMounts: [{name: tls, mountPath: /etc/tls, readOnly: true}]
  volumes:
    - name: tls
      secret: {secretName: app-cert-tls}
```
`kubectl -n config exec tls-app -- ls /etc/tls` → `ca.crt tls.crt tls.key`.
An operator watches its custom resources and creates/updates other objects (here: the Secret).

## 4.2 – Authentication, authorization, admission
```bash
kubectl -n kube-system get pod kube-apiserver-ckad-control-plane -o yaml | grep -E 'authorization-mode|enable-admission-plugins'
# --authorization-mode=Node,RBAC   --enable-admission-plugins=NodeRestriction  (+ the default-enabled plugins)
kubectl auth can-i list pods -n config --as=system:serviceaccount:config:default    # no
kubectl -n config create sa reader
kubectl -n config create role reader --verb=get,list,watch --resource=pods,configmaps
kubectl -n config create rolebinding reader --role=reader --serviceaccount=config:reader
kubectl auth can-i list configmaps -n config --as=system:serviceaccount:config:reader   # yes
```
```yaml
apiVersion: v1
kind: LimitRange
metadata: {name: cpu-max, namespace: config}
spec:
  limits: [{type: Container, max: {cpu: "1"}}]
```
`kubectl -n config run greedy --image=nginx:1.27 --overrides='{"spec":{"containers":[{"name":"greedy","image":"nginx:1.27","resources":{"requests":{"cpu":"5"},"limits":{"cpu":"5"}}}]}}'`
→ `Forbidden: maximum cpu usage per Container is 1` – rejected by the **LimitRanger admission plugin**.

Request flow: **authentication** (who are you: certs, tokens, OIDC) → **authorization** (are you
allowed: RBAC, Node) → **mutating admission** (e.g. LimitRanger defaults, ServiceAccount) →
schema validation → **validating admission** (e.g. ResourceQuota, PodSecurity) → etcd.

## 4.3 – ConfigMaps
```bash
printf 'MODE=dev\nRETRIES=3\nCOLOR=green\n' > /tmp/app.env
mkdir -p /tmp/conf.d && echo "a=1" > /tmp/conf.d/a.conf && echo "b=2" > /tmp/conf.d/b.conf
kubectl -n config create cm app-env --from-env-file=/tmp/app.env
kubectl -n config create cm app-files --from-file=/tmp/conf.d/
```
```yaml
apiVersion: v1
kind: Pod
metadata: {name: cm-consumer, namespace: config}
spec:
  containers:
    - name: c
      image: busybox:1.36
      command: ["sleep", "3600"]
      envFrom:
        - prefix: APP_
          configMapRef: {name: app-env}
      env:
        - name: THEME
          valueFrom: {configMapKeyRef: {name: app-env, key: COLOR}}
      volumeMounts: [{name: files, mountPath: /etc/conf.d}]
  volumes:
    - name: files
      configMap:
        name: app-files
        items: [{key: a.conf, path: main.conf}]
```
`--from-env-file` creates one key per line; `--from-file=<file>` creates one key with the whole
file content.

## 4.4 – Secrets
```bash
kubectl -n config create secret generic db --from-literal=user=app --from-literal=password=Pa55w0rd
openssl req -x509 -newkey rsa:2048 -nodes -days 30 -subj "/CN=web.ckad.lab" -keyout /tmp/web.key -out /tmp/web.crt
kubectl -n config create secret tls web-tls --cert=/tmp/web.crt --key=/tmp/web.key
kubectl -n config create secret docker-registry regcred --docker-server=registry.example.com \
  --docker-username=ci --docker-password=token
kubectl -n config get secret db -o jsonpath='{.data.password}' | base64 -d; echo
```
```yaml
apiVersion: v1
kind: Pod
metadata: {name: secret-consumer, namespace: config}
spec:
  imagePullSecrets: [{name: regcred}]
  containers:
    - name: c
      image: busybox:1.36
      command: ["sleep", "3600"]
      env:
        - name: DB_PASSWORD
          valueFrom: {secretKeyRef: {name: db, key: password}}
      volumeMounts: [{name: db, mountPath: /etc/db, readOnly: true}]
  volumes:
    - name: db
      secret: {secretName: db}
```
Secret data is only **base64-encoded**. Encryption at rest must be configured on the API server
(`EncryptionConfiguration`); access is controlled with RBAC.

## 4.5 – Requests, limits & QoS
```bash
kubectl -n config run qos-guaranteed --image=nginx:1.27 --overrides='{"spec":{"containers":[{"name":"c","image":"nginx:1.27","resources":{"requests":{"cpu":"100m","memory":"64Mi"},"limits":{"cpu":"100m","memory":"64Mi"}}}]}}'
kubectl -n config run qos-burstable --image=nginx:1.27 --overrides='{"spec":{"containers":[{"name":"c","image":"nginx:1.27","resources":{"requests":{"cpu":"50m","memory":"32Mi"},"limits":{"memory":"128Mi"}}}]}}'
kubectl -n config run qos-besteffort --image=nginx:1.27
kubectl -n config get pods -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass
```
Eviction order under memory pressure: **BestEffort → Burstable → Guaranteed**.
Exceeding the **memory** limit → the container is OOM-killed (exit 137). Exceeding the **CPU**
limit → the container is throttled, not killed.

## 4.6 – LimitRange & ResourceQuota
```yaml
apiVersion: v1
kind: LimitRange
metadata: {name: container-limits, namespace: quota-demo}
spec:
  limits:
    - type: Container
      defaultRequest: {cpu: 100m, memory: 64Mi}
      default: {cpu: 200m, memory: 128Mi}
      min: {memory: 16Mi}
      max: {memory: 256Mi}
---
apiVersion: v1
kind: ResourceQuota
metadata: {name: team-quota, namespace: quota-demo}
spec:
  hard:
    requests.cpu: "1"
    requests.memory: 512Mi
    limits.memory: 1Gi
    pods: "5"
    configmaps: "3"
```
```bash
kubectl -n quota-demo create deploy fill --image=nginx:1.27 --replicas=8
kubectl -n quota-demo get pods                     # 5 pods (pods limit) – cpu: 5 × 100m = 500m fits
kubectl -n quota-demo describe quota team-quota
kubectl -n quota-demo describe rs | grep -i exceeded
```
Every namespace contains the ConfigMap `kube-root-ca.crt` – it counts against `configmaps: 3`.
Once a quota covers `requests.*`/`limits.*`, every pod **must** specify them – the LimitRange
defaults make that automatic.

## 4.7 – ServiceAccounts
```yaml
apiVersion: v1
kind: ServiceAccount
metadata: {name: app-sa, namespace: config}
automountServiceAccountToken: false
---
apiVersion: v1
kind: Pod
metadata: {name: sa-pod, namespace: config}
spec:
  serviceAccountName: app-sa
  containers:
    - name: c
      image: busybox:1.36
      command: ["sleep", "3600"]
      volumeMounts: [{name: token, mountPath: /var/run/secrets/tokens}]
  volumes:
    - name: token
      projected:
        sources:
          - serviceAccountToken:
              audience: my-api
              expirationSeconds: 3600
              path: api
```
```bash
kubectl -n config exec sa-pod -- cat /var/run/secrets/tokens/api | cut -d. -f2 | base64 -d 2>/dev/null; echo
# "aud":["my-api"], "sub":"system:serviceaccount:config:app-sa"
```
The kubelet rotates projected tokens automatically before they expire.

## 4.8 – SecurityContext
```yaml
apiVersion: v1
kind: Pod
metadata: {name: secure, namespace: config}
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
    seccompProfile: {type: RuntimeDefault}
  containers:
    - name: c
      image: busybox:1.36
      command: ["sleep", "3600"]
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]
          add: ["NET_BIND_SERVICE"]
      volumeMounts: [{name: tmp, mountPath: /tmp}]
  volumes:
    - {name: tmp, emptyDir: {}}
```
```bash
kubectl -n config exec secure -- id                   # uid=1000 gid=3000 groups=2000
kubectl -n config exec secure -- touch /test          # Read-only file system
kubectl -n config exec secure -- sh -c 'touch /tmp/test && ls -ln /tmp/test'   # group 2000
```
Container-level settings override pod-level ones. `capabilities` only exist at container level.

## 4.9 – Pod Security Admission
```bash
kubectl create ns restricted-apps
kubectl label ns restricted-apps pod-security.kubernetes.io/enforce=restricted
kubectl -n restricted-apps run web --image=nginx:1.27
# Error: violates PodSecurity "restricted:latest": allowPrivilegeEscalation != false, unrestricted capabilities,
# runAsNonRoot != true, seccompProfile ...
```
```yaml
apiVersion: v1
kind: Pod
metadata: {name: compliant, namespace: restricted-apps}
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 101
    seccompProfile: {type: RuntimeDefault}
  containers:
    - name: web
      image: nginxinc/nginx-unprivileged:1.27-alpine
      securityContext:
        allowPrivilegeEscalation: false
        capabilities: {drop: ["ALL"]}
```
