
helm list -A

ps aux | grep "[p]ort-forward svc" | awk '{print $2}' | xargs kill -9
ps -ef|grep port-forward

##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### 
##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### 

# Удаление приложения FastAPI
helm uninstall bitcoin-price -n test-bitcoin-price

# Prometheus + Grafana stack
helm uninstall monitoring -n monitoring

# OpenTelemetry Collector
helm uninstall otel-collector -n monitoring

# Удаление Jaeger (если устанавливался как Helm-релиз)
helm uninstall jaeger -n monitoring

# Karpenter и его CRD
helm uninstall karpenter -n karpenter
helm uninstall karpenter-crd -n karpenter


##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### 
##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### 

### Удаление ресурсов Karpenter ###

# Удаление NodePool и EC2NodeClass
kubectl delete nodepool mixed-capacity --grace-period=0 --force
kubectl delete ec2nodeclass mixed-capacity --grace-period=0 --force

kubectl get crds | grep karpenter
# Если есть, то:
kubectl delete crd ec2nodeclasses.karpenter.k8s.aws --grace-period=0 --force

# Удаление namespace (если хочешь очистить полностью)
kubectl delete ns karpenter

##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### 
##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### #####

### Удаление ECR репозитория ###
aws ecr delete-repository --repository-name bitcoin-api --force

##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### 
##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### #####

# Scale Down Node-Group
Desired size = 2
Minimum size = 1
Maximum size = 5
