# 4. Autoscaling with Karpenter #

cd ~/Interlore/Git/homework_stealth/autoscaling_with_karpenter

export ACCOUNT_ID="389426476195"
export REGION="us-west-2"
export CLUSTER_NAME="affico360-dev-eks-01"
export KARPENTER_VERSION="1.4.0"
export KARPENTER_NAMESPACE="karpenter"


## 1.0. Creating an IAM role for Karpenter: It will be bound to karpenter-controller and will allow you to manage EC2. #

## 1.0.1. Create SQS ##
aws sqs create-queue --queue-name karpenter-interruption-queue
aws sqs list-queues | grep karpenter

## 1.0.2. Adding tags for karpenter on subnet
aws ec2 create-tags \
  --resources "subnet-09948a89e6fe11ca2" "subnet-0e0499c81832d6333" "subnet-0c0cf25278411294f" \
  --tags Key=karpenter.sh/discovery,Value=${CLUSTER_NAME} \
  --region ${REGION}

aws ec2 create-tags \
  --resources sg-09e09f550c6933a88 \
  --tags Key=karpenter.sh/discovery,Value=${CLUSTER_NAME} \
  --region ${REGION}


### Validation Tags ###
aws ec2 describe-subnets \
  --filters "Name=tag:karpenter.sh/discovery,Values=${CLUSTER_NAME}" \
  --region ${REGION} \
  --query 'Subnets[*].[SubnetId,Tags]'

aws ec2 describe-security-groups \
  --filters "Name=tag:karpenter.sh/discovery,Values=${CLUSTER_NAME}" \
  --region us-west-2 \
  --query "SecurityGroups[*].[GroupId,GroupName,Tags]"

## 1.0.3. Create IAM Role
aws iam create-role --role-name KarpenterControllerRole-eks-affico360 \
  --assume-role-policy-document file://trust-policy.json

aws iam put-role-policy \
  --role-name KarpenterControllerRole-eks-affico360 \
  --policy-name KarpenterSQSAccessPolicy \
  --policy-document file://sqs-policy.json

aws iam put-role-policy \
  --role-name affico360-dev-managed-ng-01 \
  --policy-name KarpenterPricingAccess \
  --policy-document file://karpenter-pricing-policy.json

aws iam put-role-policy \
  --role-name KarpenterControllerRole-eks-affico360 \
  --policy-name KarpenterPricingAccess \
  --policy-document file://karpenter-pricing-policy.json

aws iam create-policy \
  --policy-name KarpenterPricingPolicy \
  --policy-document file://karpenter-pricing-policy.json

aws iam attach-role-policy \
  --role-name KarpenterControllerRole-eks-affico360 \
  --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/KarpenterPricingPolicy

aws iam put-role-policy \
  --role-name affico360-dev-managed-ng-01 \
  --policy-name KarpenterEC2Access \
  --policy-document file://karpenter-ec2-policy.json

aws iam put-role-policy \
  --role-name KarpenterControllerRole-eks-affico360 \
  --policy-name KarpenterRunInstancesAccess \
  --policy-document file://karpenter-ec2-runinstances-policy.json

aws iam put-role-policy \
  --role-name KarpenterControllerRole-eks-affico360 \
  --policy-name KarpenterFleetPermission \
  --policy-document file://karpenter-create-fleet-policy.json

aws iam put-role-policy \
  --role-name KarpenterControllerRole-eks-affico360 \
  --policy-name KarpenterCreateFleetPolicy \
  --policy-document file://karpenter-create-fleet-policy.json

aws iam put-role-policy \
  --role-name KarpenterControllerRole-eks-affico360 \
  --policy-name KarpenterCreateFleetAccess \
  --policy-document file://karpenter-create-fleet-policy.json

## 1.1. Attach the necessary policies to the role. ##
aws iam attach-role-policy \
  --role-name KarpenterControllerRole-eks-affico360 \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy

aws iam attach-role-policy \
  --role-name KarpenterControllerRole-eks-affico360 \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly

aws iam attach-role-policy \
  --role-name KarpenterControllerRole-eks-affico360 \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

aws iam attach-role-policy \
  --role-name KarpenterControllerRole-eks-affico360 \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
  

## 1.3. Create Instance Profile ##
aws iam create-instance-profile \
  --instance-profile-name KarpenterNodeInstanceProfile-eks-affico360

aws iam add-role-to-instance-profile \
  --instance-profile-name KarpenterNodeInstanceProfile-eks-affico360 \
  --role-name KarpenterControllerRole-eks-affico360

## 1.4. Create a ServiceAccount via IAM OIDC provider ##
eksctl utils associate-iam-oidc-provider --region ${REGION} --cluster ${CLUSTER_NAME} --approve

## 1.5. Bind IAM role ##
### Note: "iamserviceaccount" already exists during previous installation - NO NEED to run !!! ###
eksctl create iamserviceaccount \
  --cluster ${CLUSTER_NAME} \
  --namespace ${KARPENTER_NAMESPACE} \
  --name karpenter \
  --attach-policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/KarpenterControllerPolicy \
  --approve \
  --role-name KarpenterControllerRole-eks-affico360

## Step 2: Install Karpenter via Helm
### Note:: https://karpenter.sh/docs/getting-started/getting-started-with-karpenter/

# Logout of helm registry to perform an unauthenticated pull against the public ECR
helm registry logout public.ecr.aws
# Login without password, just press Enter.
helm registry login public.ecr.aws

kubectl delete crd ec2nodeclasses.karpenter.k8s.aws nodepools.karpenter.sh

helm upgrade --install karpenter-crd oci://public.ecr.aws/karpenter/karpenter-crd \
  --version ${KARPENTER_VERSION} \
  --namespace ${KARPENTER_NAMESPACE} --create-namespace

# For Uninstall Action ## > helm uninstall karpenter -n karpenter
helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --version ${KARPENTER_VERSION} \
  --namespace ${KARPENTER_NAMESPACE} --create-namespace \
  -f karpenter-values.yaml

## Step 3: Create a Provisioner ##
kubectl get crd | grep karpenter
kubectl explain ec2nodeclasses.karpenter.k8s.aws
kubectl explain nodepools.karpenter.sh

kubectl apply -f ec2nodeclass.yaml
kubectl apply -f nodepool.yaml

kubectl apply -f karpenter-sa.yaml

## 3.1: Validation installation ##

kubectl get nodepools
kubectl describe nodepool mixed-capacity
kubectl get ec2nodeclasses

kubectl get pods -o wide
kubectl get pods -n karpenter
kubectl get sa -n karpenter karpenter -o yaml

kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter

aws sqs get-queue-attributes \
  --queue-url https://sqs.us-west-2.amazonaws.com/389426476195/karpenter-interruption-queue \
  --attribute-name All

## Restart deployment after adding IAM Role ##
kubectl rollout restart deploy karpenter -n karpenter
kubectl get pods -n karpenter

## 4.0: Run Scale Test ##
kubectl apply -f scale-test.yaml

## 4.1: What should happen ##
1. There are 10 pods, each requiring 1 CPU and 1Gi RAM.
2. There is no room for them on the current nodes → they will go into the Pending status.
3. Karpenter will see them and create EC2 instances suitable for your NodePool.

kubectl get pods -w
kubectl get nodes -w
# Observe new node claims being created with: #
kubectl get nodeclaims -A -w
aws ec2 describe-instances \
  --filters "Name=tag:karpenter.sh/nodepool,Values=mixed-capacity" \
  --query "Reservations[*].Instances[*].[InstanceId,PrivateDnsName,State.Name]" \
  --output table

# Tail logs to see scheduling decisions in real time: #
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=100 -f

## 4.2: Remove Scale Test ##
kubectl delete deployment scale-test


### What Achieved ###
* Successfully deployed Karpenter into the EKS cluster affico360-dev-eks-01 (region: us-west-2).
* Configured a dynamic NodePool (mixed-capacity) with support for both spot and on-demand instances (t3a.medium, t3a.large).
* Attached the required IAM roles and permissions, including ec2:RunInstances, to allow Karpenter to provision and terminate EC2 nodes.
* Launched NodeClaims automatically in response to pod scheduling pressure from the scale-test deployment.
* Verified automatic cleanup behavior of Karpenter — idle nodes were terminated after the deployment was removed, thanks to:
* consolidationPolicy: WhenEmptyOrUnderutilized
* consolidateAfter: 30s
* Confirmed full lifecycle:
* Deployment → Pod scheduling → Node provisioning → Pod termination → Node consolidation.