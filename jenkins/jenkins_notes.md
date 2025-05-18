# Create AWS ECR repository
aws ecr create-repository \
  --repository-name bitcoin-price-service \
  --region us-west-2

### What Achieved (Jenkins CI/CD) ###

1. **Automated CI/CD Pipeline with Jenkins**  
   A complete CI/CD flow was implemented using a declarative Jenkins pipeline to automate application deployment to EKS.

2. **Kubernetes YAML Linting**  
   Integrated [`kube-linter`](https://github.com/stackrox/kube-linter) for static analysis of Kubernetes manifests to catch misconfigurations before deployment.

3. **Docker Image Build & Push to ECR**  
   The pipeline builds the FastAPI application's Docker image and securely pushes it to AWS Elastic Container Registry (ECR), using Jenkins credentials and AWS CLI.

4. **Helm-Based Deployment**  
   Used `helm upgrade --install` to manage Kubernetes resources declaratively. Supports both initial deployment and updates.

5. **Dynamic Image Tagging**  
   Docker image tags are aligned with Jenkins build numbers for traceability.

6. **(Optional) Prometheus Reload or Notification**  
   The pipeline includes an optional hook to reload Prometheus configuration or send Slack notifications after successful deployment.