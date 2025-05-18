Replace "389854136195" to "<real_account_id>" - in ALL FILES !!!!

# 1. Microservice Deployment with Helm #
cd ~/Interlore/Git/homework_stealth
export ACCOUNT_ID="389854136195"

# Create Docker Image
docker build --platform linux/amd64,linux/arm64 -t bitcoin-api .
docker images | grep bitcoin-api

# Create AWS ECR
aws ecr create-repository \
  --repository-name bitcoin-api \
  --region us-west-2

# Log-In to AWS ECR
aws ecr get-login-password --region us-west-2 | \
docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com

# Upload Docker Image to AWS ECR
docker tag bitcoin-api:latest ${ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com/bitcoin-api:latest
docker push ${ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com/bitcoin-api:latest
aws ecr list-images --repository-name bitcoin-api --region us-west-2

# Dry Run #
helm upgrade --install bitcoin-price ./helm/bitcoin-price \
  --namespace test-bitcoin-price \
  --debug --dry-run

# Install First Time Helm #
helm upgrade --install bitcoin-price ./helm/bitcoin-price \
  --namespace test-bitcoin-price \
  --create-namespace

helm upgrade --install bitcoin-price ./helm/bitcoin-price \
  --namespace test-bitcoin-price \
  --create-namespace --atomic --debug

# Re-Install Helm #
docker buildx build --no-cache --platform linux/amd64,linux/arm64 -t ${ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com/bitcoin-api:latest --push .

helm upgrade --install bitcoin-price ./helm/bitcoin-price \
  --namespace test-bitcoin-price \
  --atomic

kubectl delete pod -n test-bitcoin-price --all
kubectl get pods -n test-bitcoin-price

# Validate Helm and Installation #
helm list -n test-bitcoin-price
helm get all bitcoin-price -n test-bitcoin-price

kubectl get pods -n test-bitcoin-price
kubectl get svc -n test-bitcoin-price
kubectl describe pods -n test-bitcoin-price

kubectl port-forward svc/test-api-service 8000:80 -n test-bitcoin-price > /dev/null 2>&1 &
ps -ef|grep port-forward

# Get Price #
curl http://localhost:8000/price

# Check Liveness Service #
curl http://localhost:8000/healthz

# Auto Test
./curl-test.sh


### What Achieved ###
* Helm chart — with deployment.yaml, service.yaml, and values.yaml
* ECR — multi-platform image built for both ARM and AMD architectures
* FastAPI — resilient to CoinGecko API failures
* Readiness/Liveness — implemented without harming the service
* Full cycle: Debug → Build → Deploy → Profit 

##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### 
##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### 

# 2. Observability with Prometheus and Grafana #

## Architecture ##
FastAPI App
  ↳ Exposes /metrics via prometheus_client
  ↳ Exposes /healthz for probes

Prometheus (Helm)
  ↳ Discovers FastAPI pod via serviceMonitor
  ↳ Scrapes /metrics

Grafana (Helm)
  ↳ Connects to Prometheus
  ↳ Dashboards for FastAPI

# Install Prometheus Stack #
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.enabled=true \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

# Test Grafana Connection #
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80 > /dev/null 2>&1 &
## via Web-Browser ##
http://localhost:3000
user: admin
pass: prom-operator

## After adding "/metrics" to deployment.yaml and "servicemonitor.yaml" file ##
helm upgrade --install bitcoin-price ./helm/bitcoin-price \
  --namespace test-bitcoin-price --atomic


# Test and validate if service provide metrics #
kubectl get servicemonitor -n test-bitcoin-price
kubectl describe servicemonitor bitcoin-api-monitor -n test-bitcoin-price

curl http://localhost:8000/metrics

## Check Prometheus ##
kubectl port-forward svc/monitoring-kube-prometheus-prometheus 9090 -n monitoring > /dev/null 2>&1 &
## via Web-Browser ##
http://localhost:9090/targets

### What Achieved ###
* Integrated FastAPI application with Prometheus using the /metrics endpoint
* Created a ServiceMonitor resource to allow automatic discovery by Prometheus
* Configured accurate Kubernetes labels and annotations for reliable metric scraping
* Deployed the full kube-prometheus-stack using Helm, including Prometheus and Grafana
* Verified that Prometheus successfully scrapes metrics from the service
* Enabled access to Grafana for visualizing metrics like price_requests_total
* Built a fully observable microservice with production-ready monitoring

##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### 
##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### 

# 3. Distributed Tracing with OpenTelemetry and Jaeger(Bonus Observability) #

# Install OpenTelemetry Collector and Jaeger #
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

## OpenTelemetry Collector ##
helm upgrade --install otel-collector open-telemetry/opentelemetry-collector \
  --namespace monitoring \
  --create-namespace \
  --set mode=deployment \
  --set image.repository=otel/opentelemetry-collector \
  --set config.exporters.jaeger.endpoint="jaeger.monitoring.svc.cluster.local:14250" \
  --set config.exporters.jaeger.tls.enabled=false \
  --set config.receivers.otlp.protocols.http.endpoint="0.0.0.0:4318"

## Jaeger ##
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update

helm upgrade --install jaeger jaegertracing/jaeger \
  --namespace monitoring \
  --create-namespace \
  --set collector.enabled=true \
  --set query.enabled=true \
  --set storage.type=memory \
  --set agent.enabled=true \
  --set allInOne.enabled=true


# After adding OpenTelemetry Collector and Jaeger #
# Re-Install Helm #
docker buildx build --no-cache --platform linux/amd64,linux/arm64 -t ${ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com/bitcoin-api:latest --push .

helm upgrade --install bitcoin-price ./helm/bitcoin-price \
  --namespace test-bitcoin-price \
  --atomic

kubectl delete pod -n test-bitcoin-price --all
kubectl get pods -n test-bitcoin-price

# Check Jaeger Installation #
kubectl get pods -n monitoring -l app.kubernetes.io/component=query
kubectl get svc -n monitoring | grep jaeger

#### Test connection to Jaeger ####
# Option A #
kubectl port-forward svc/jaeger-query 16686:16686 -n monitoring > /dev/null 2>&1 &
# Option B #
export POD_NAME=$(kubectl get pods --namespace monitoring -l "app.kubernetes.io/instance=jaeger,app.kubernetes.io/component=query" -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward --namespace monitoring $POD_NAME 8080:16686 > /dev/null 2>&1 &

## via Web-Browser ##
http://localhost:16686

# Create manually triggered trace 
curl http://localhost:8000/trace-test

### What Achieved ###
* Integrated OpenTelemetry SDK into your FastAPI app with proper trace.get_tracer() usage
* Exposed a /trace-test endpoint that creates spans for tracing validation
* Configured environment variables to export traces using OTLP protocol over HTTP
* Deployed OpenTelemetry Collector in deployment mode, with Jaeger exporter targeting jaeger.monitoring.svc.cluster.local:14250
* Switched Jaeger to in-memory storage for lightweight demo and ease of setup
* Exposed Jaeger UI via port-forwarding to view service traces
* Validated full E2E trace delivery from app → collector → Jaeger UI

##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### 
##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### 

# 4. Autoscaling with Karpenter #
~/Interlore/Git/homework_stealth/autoscaling_with_karpenter/autoscaling_with_karpenter_notes.md


##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### 
##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### 

# !!!! All Tests in one place !!!! #
ps -ef|grep port-forward

##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### #####
#### Test connection to "bitcoin-price" appl ####
##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### #####
kubectl port-forward svc/test-api-service 8000:80 -n test-bitcoin-price > /dev/null 2>&1 &

curl http://localhost:8000/metrics
curl http://localhost:8000/price
curl http://localhost:8000/healthz

##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### #####
#### Test connection to Grafana ####
##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### #####
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80 > /dev/null 2>&1 &

## via Web-Browser ##
http://localhost:3000
user: admin
pass: prom-operator

##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### #####
#### Test connection to Prometheus ####
##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### #####
kubectl port-forward svc/monitoring-kube-prometheus-prometheus 9090 -n monitoring > /dev/null 2>&1 &

## via Web-Browser ##
http://localhost:9090/targets

##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### #####
#### Test connection to Jaeger ####
##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### #####
# Option A #
kubectl port-forward svc/jaeger-query 16686:16686 -n monitoring > /dev/null 2>&1 &
# Option B #
export POD_NAME=$(kubectl get pods --namespace monitoring -l "app.kubernetes.io/instance=jaeger,app.kubernetes.io/component=query" -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward --namespace monitoring $POD_NAME 8080:16686 > /dev/null 2>&1 &

## via Web-Browser ##
http://localhost:16686

# Create manually triggered trace 
curl http://localhost:8000/trace-test

##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### #####
ps -ef|grep port-forward
ps aux | grep "[p]ort-forward svc" | awk '{print $2}' | xargs kill -9


kubectl port-forward svc/test-api-service 8000:80 -n test-bitcoin-price > /dev/null 2>&1 &
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80 > /dev/null 2>&1 &
kubectl port-forward svc/monitoring-kube-prometheus-prometheus 9090 -n monitoring > /dev/null 2>&1 &
kubectl port-forward svc/jaeger-query 16686:16686 -n monitoring > /dev/null 2>&1 &

curl http://localhost:8000/price
curl http://localhost:8000/trace-test

##### ##### ##### ##### ##### ##### ##### ##### ##### ##### ##### #####
