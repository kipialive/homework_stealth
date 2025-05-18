# DevOps Assignment – Cymulate

## Overview

This project demonstrates a Kubernetes microservice deployment using FastAPI, Helm, Docker, and observability tools such as Prometheus, Grafana, OpenTelemetry, and Jaeger. It also includes autoscaling with Karpenter, CI/CD with Jenkins, and optional Terraform-based infrastructure provisioning.

---

## Project Structure

```bash
.
├── app
│   └── main.py
├── autoscaling_with_karpenter
│   ├── *.yaml, *.json, karpenter notes
├── bitcoin_price_notes.md
├── curl-test.sh
├── Dockerfile
├── helm
│   └── bitcoin-price (Helm chart)
├── jenkins
│   ├── Jenkinsfile, jenkins_notes.md
├── requirements.txt
├── screenshots
│   └── Grafana, Jaeger, Prometheus, Logs
└── terraform
    ├── environments/affico360-dev
    └── modules/network
```

---

## 1. Microservice Deployment with Helm

### What Achieved
- Helm chart with deployment.yaml, service.yaml, and values.yaml
- ECR — multi-platform Docker image (ARM & AMD)
- FastAPI with graceful handling of CoinGecko API failures
- Readiness & liveness probes implemented
- Debug → Build → Deploy → Validate

---

## 2. Observability with Prometheus & Grafana

### What Achieved
- /metrics endpoint integrated with FastAPI
- `ServiceMonitor` configured for Prometheus discovery
- Full kube-prometheus-stack deployed via Helm
- Grafana dashboard accessible and connected to Prometheus
- Metrics like `price_requests_total` tracked and visualized

---

## 3. Distributed Tracing with OpenTelemetry & Jaeger

### What Achieved
- OpenTelemetry SDK integrated in FastAPI
- Custom `/trace-test` endpoint emitting spans
- OTLP traces sent via OpenTelemetry Collector → Jaeger
- In-memory Jaeger used for simplicity
- Full E2E trace validation complete

---

## 4. Autoscaling with Karpenter

### What Achieved
- Karpenter deployed in EKS (cluster: `affico360-dev-eks-01`)
- Dynamic NodePool (`mixed-capacity`) with spot/on-demand
- Node provisioning triggered by pod pressure
- Automatic termination of idle nodes using:
  - `consolidationPolicy: WhenEmptyOrUnderutilized`
  - `consolidateAfter: 30s`

---

## 5. CI/CD with Jenkins

### What Achieved
- Declarative `Jenkinsfile` for CI/CD pipeline
- Kubernetes YAML linting with `kube-linter`
- Docker image build + push to AWS ECR
- Helm-based upgrade/install to EKS
- Tagged builds for traceability
- Optional Prometheus reload or Slack notification

---

## 6. Terraform Infrastructure (Optional)

### What Achieved
- VPC, subnets, NAT Gateway
- Amazon EKS Cluster setup
- Amazon RDS PostgreSQL instance

---

## Access & Testing

```bash
# Service Endpoints (via port-forward)
svc/test-api-service:              8000:80      -n test-bitcoin-price
svc/monitoring-grafana:            3000:80      -n monitoring
svc/monitoring-kube-prometheus:    9090         -n monitoring
svc/jaeger-query:                  16686:16686  -n monitoring
```

---

## Visuals (in /screenshots)

- Grafana Dashboard
- Jaeger Traces
- Prometheus Targets
- Karpenter NodeClaim Logs
- Pod/Service connectivity logs

---

## Notes

- Everything works with minimal manual steps once configured
- Designed for flexibility, observability, and production realism
- Includes fallback handling, readiness gates, and auto-scaling

---

## Author

Vladimir Vyazmin  
Senior DevOps & FinOps Specialist  
🇮🇱 Built with passion and observability in mind.