#!/bin/bash

# AWS ECR Setup Script for Flask Static App
# This script sets up the necessary ECR repository and permissions

set -e

# Variables
AWS_REGION=${AWS_REGION:-"us-east-1"}
REPOSITORY_NAME="flask-static-app"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Setting up ECR repository for Flask Static App"
echo "AWS Account ID: ${AWS_ACCOUNT_ID}"
echo "Region: ${AWS_REGION}"
echo "Repository: ${REPOSITORY_NAME}"

# Create ECR repository if it doesn't exist
echo "Creating ECR repository..."
aws ecr create-repository \
    --repository-name ${REPOSITORY_NAME} \
    --region ${AWS_REGION} \
    --image-scanning-configuration scanOnPush=true \
    --encryption-configuration encryptionType=AES256 \
    2>/dev/null || echo "Repository ${REPOSITORY_NAME} already exists"

# Get repository URI
REPOSITORY_URI=$(aws ecr describe-repositories \
    --repository-names ${REPOSITORY_NAME} \
    --region ${AWS_REGION} \
    --query 'repositories[0].repositoryUri' \
    --output text)

echo "ECR Repository URI: ${REPOSITORY_URI}"

# Set lifecycle policy to manage image retention
echo "Setting lifecycle policy..."
aws ecr put-lifecycle-policy \
    --repository-name ${REPOSITORY_NAME} \
    --region ${AWS_REGION} \
    --lifecycle-policy-text '{
        "rules": [
            {
                "rulePriority": 1,
                "description": "Keep last 10 images",
                "selection": {
                    "tagStatus": "any",
                    "countType": "imageCountMoreThan",
                    "countNumber": 10
                },
                "action": {
                    "type": "expire"
                }
            }
        ]
    }' || echo "Lifecycle policy already exists"

echo ""
echo "✅ ECR setup completed successfully!"
echo ""
echo "📝 Update your Azure Pipeline with:"
echo "   ecrRegistry: '${REPOSITORY_URI%/*}'"
echo "   AWS_ACCOUNT_ID: '578478003474'"
echo ""
echo "🔐 Test ECR login:"
echo "   aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${REPOSITORY_URI%/*}"
echo ""
echo "🚀 Build and push test image:"
echo "   docker build -t ${REPOSITORY_NAME} ./src"
echo "   docker tag ${REPOSITORY_NAME}:latest ${REPOSITORY_URI}:latest"
echo "   docker push ${REPOSITORY_URI}:latest"