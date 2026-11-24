# CKAD Cheatsheet

## Setup in the exam terminal
```bash
alias k=kubectl
export do="--dry-run=client -o yaml"
export now="--force --grace-period=0"
k config set-context --current --namespace=<ns>     # saves typing -n
```

## Generate YAML fast
```bash
k run p --image=nginx:1.27 --port=80 --labels=app=web --env=K=V $do
k run p --image=busybox:1.36 $do -- sh -c 'sleep 3600'      # args after --
k run p --image=busybox:1.36 --command $do -- sleep 3600    # command instead of args
k create deploy d --image=nginx:1.27 --replicas=3 $do
k create job j --image=busybox:1.36 $do -- echo hi
k create cronjob c --image=busybox:1.36 --schedule="*/5 * * * *" $do -- date
k create cm c --from-literal=K=V --from-file=f.conf --from-env-file=.env
k create secret generic s --from-literal=pw=x --from-file=./key
k create secret tls t --cert=c.crt --key=c.key
k create secret docker-registry r --docker-server=reg --docker-username=u --docker-password=p
k create sa sa1 ; k create token sa1 --duration=1h
k create role r --verb=get,list --resource=pods ; k create rolebinding rb --role=r --serviceaccount=ns:sa1
k create quota q --hard=pods=5,requests.memory=1Gi
k create ingress i --class=traefik --rule="host/path*=svc:80,tls=secret"   # path* = Prefix, path = Exact
k expose deploy d --port=80 --target-port=8080 [--type=NodePort] [--name=x]
```

## Change running things
```bash
k set image deploy/d c=nginx:1.27
k set env deploy/d K=V ; k set env deploy/d --from=configmap/cm [--prefix=X_]
k set resources deploy/d --requests=cpu=100m,memory=64Mi --limits=cpu=200m,memory=128Mi
k set serviceaccount deploy/d sa1
k set selector svc s app=web
k scale deploy d --replicas=5 ; k autoscale deploy d --min=2 --max=5 --cpu-percent=70
k rollout status|history|undo|pause|resume|restart deploy/d [--to-revision=N]
k replace --force -f pod.yaml                  # change immutable pod fields
k patch svc s -p '{"spec":{"selector":{"v":"green"}}}'
```

## Images
```bash
docker build -t app:1.0 .                     # podman build ...
docker build --build-arg V=2 -t app:2.0 .
docker save app:1.0 -o app.tar                 # podman save --format oci-archive -o app.tar app:1.0
kind load docker-image app:1.0 --name ckad     # kind load image-archive app.tar --name ckad
```
Dockerfile basics: `FROM`, `ARG`, `ENV`, `WORKDIR`, `COPY [--chown] [--chmod]`, `RUN`, `USER`, `EXPOSE`,
`ENTRYPOINT` + `CMD`, multi-stage `FROM x AS build` / `COPY --from=build`.

## Helm
```bash
helm repo add n url ; helm repo update ; helm search repo n/chart --versions
helm show values n/chart
helm install rel n/chart -n ns --create-namespace --set k=v -f values.yaml [--version x]
helm upgrade rel n/chart --reuse-values --set k=v ; helm rollback rel 1
helm list -A [--all] ; helm history rel ; helm get values rel ; helm uninstall rel [--keep-history]
helm template rel n/chart -f values.yaml > out.yaml
```

## Kustomize
```yaml
resources: [../base]
namespace: x
namePrefix: p- ; nameSuffix: -s
labels: [{pairs: {env: prod}, includeSelectors: true}]
replicas: [{name: api, count: 3}]
images: [{name: nginx, newTag: 1.27-alpine}]
configMapGenerator: [{name: cfg, literals: [K=V]}]
patches:
  - path: patch.yaml                      # strategic merge
  - target: {kind: Deployment, name: api} # JSON 6902
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 2
```
`k kustomize dir` (preview) · `k apply -k dir`

## Pod spec snippets
```yaml
initContainers:
  - {name: sidecar, image: busybox, restartPolicy: Always, command: [...]}   # native sidecar
securityContext:            # pod: runAsUser, runAsGroup, runAsNonRoot, fsGroup, seccompProfile
containers:
  - securityContext:        # container: allowPrivilegeEscalation, readOnlyRootFilesystem, capabilities, privileged
    startupProbe | readinessProbe | livenessProbe:
      httpGet: {path: /, port: 80} | tcpSocket: {port: 80} | exec: {command: [...]}
      initialDelaySeconds, periodSeconds, failureThreshold, successThreshold, timeoutSeconds
    envFrom: [{prefix: X_, configMapRef: {name: cm}}, {secretRef: {name: s}}]
    env: [{name: K, valueFrom: {configMapKeyRef|secretKeyRef: {name: x, key: k}}}]
volumes:
  - emptyDir: {medium: Memory, sizeLimit: 64Mi}
  - configMap: {name: cm, items: [{key: k, path: file}]}
  - secret: {secretName: s, defaultMode: 0400}
  - persistentVolumeClaim: {claimName: pvc}
  - projected: {sources: [{serviceAccountToken: {audience: a, expirationSeconds: 3600, path: t}}]}
```

## Debugging
```bash
k describe pod p ; k get events --sort-by=.lastTimestamp [--field-selector type=Warning]
k logs p -c c [--previous] [--since=5m] [--tail=20] [-f] ; k logs -l app=x --all-containers --prefix
k exec -it p -c c -- sh ; k port-forward svc/s 8080:80
k debug -it p --image=busybox --target=c            # ephemeral container
k debug p --copy-to=p-debug --set-image=c=busybox -- sleep 3600
k debug node/n -it --image=busybox                  # node fs under /host
k top pods --sort-by=memory --containers
k get pods -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass,RESTARTS:.status.containerStatuses[0].restartCount
k api-resources ; k api-versions ; k explain <kind>.spec --recursive
```
