#!/bin/bash

# Script to create ECR registry secret for Kubernetes
# This script should be run as part of the deployment pipeline

set -e

# Variables (these will be set by the pipeline)
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-"123456789012"}
AWS_REGION=${AWS_REGION:-"us-east-1"}
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
NAMESPACE=${NAMESPACE:-"default"}
SECRET_NAME="ecr-registry-secret"

echo "Creating ECR registry secret for namespace: ${NAMESPACE}"

# Get ECR login token
TOKEN=$(aws ecr get-login-password --region ${AWS_REGION})

# Create or update the secret
kubectl create secret docker-registry ${SECRET_NAME} \
  --namespace=${NAMESPACE} \
  --docker-server=${ECR_REGISTRY} \
  --docker-username=AWS \
  --docker-password=${TOKEN} \
  --dry-run=client -o yaml | kubectl apply -f -

echo "ECR registry secret created/updated successfully"

# Patch the default service account to use the secret
kubectl patch serviceaccount deploy-robot \
  -p '{"imagePullSecrets": [{"name": "'${SECRET_NAME}'"}]}' \
  --namespace=${NAMESPACE}

echo "Service account patched to use ECR secret"