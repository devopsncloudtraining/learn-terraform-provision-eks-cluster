# Flask Static Website Deployment Guide

This repository contains the complete setup for deploying a Python Flask static website to AWS EKS using Azure DevOps Pipelines.

## Project Structure

```
├── src/                          # Flask application source code
│   ├── app.py                   # Main Flask application
│   ├── requirements.txt         # Python dependencies
│   ├── Dockerfile              # Docker container configuration
│   ├── .dockerignore           # Docker ignore patterns
│   ├── static/                 # Static assets (CSS, JS, images)
│   │   └── style.css           # Application styles
│   └── templates/              # HTML templates
│       ├── index.html          # Home page template
│       └── about.html          # About page template
├── manifests/                   # Kubernetes deployment manifests
│   ├── deployment.yaml         # Application deployment
│   ├── service.yaml            # Kubernetes service
│   ├── ingress.yaml            # Ingress configuration (ALB)
│   ├── configmap.yaml          # Configuration data
│   ├── serviceaccount-ecr.yaml # Service account for ECR access
│   ├── pdb.yaml                # Pod Disruption Budget
│   └── hpa.yaml                # Horizontal Pod Autoscaler
├── scripts/                     # Helper scripts
│   └── setup-ecr-secret.sh     # ECR authentication script
├── terraform files...          # EKS infrastructure (existing)
└── azure-pipelines-iac-tf-eks.yml # Azure DevOps pipeline
```

## Application Features

### Flask Application
- **Framework**: Python Flask 3.0.0
- **Server**: Gunicorn WSGI server
- **Port**: 80 (HTTP)
- **Health Check**: `/health` endpoint
- **Security**: Non-root user, read-only filesystem options

### Pages
- **Home** (`/`): Welcome page with feature list
- **About** (`/about`): Technology stack and architecture info
- **Health** (`/health`): Health check endpoint for monitoring

## Infrastructure Components

### AWS Resources (Terraform)
- EKS Cluster
- VPC and networking
- Security groups
- IAM roles and policies

### Kubernetes Resources
- **Deployment**: 3 replicas with resource limits and health checks
- **Service**: ClusterIP service for internal communication
- **Ingress**: AWS ALB for external access on port 80
- **ConfigMap**: Environment configuration
- **HPA**: Auto-scaling based on CPU (70%) and memory (80%) usage
- **PDB**: Ensures minimum availability during updates

## Pipeline Stages

### 1. Infrastructure Stage
- Terraform installation and initialization
- EKS cluster provisioning
- Kubeconfig update

### 2. Build Stage
- Docker image build from Flask application
- ECR login authentication
- Push to AWS Elastic Container Registry (ECR)
- Image tagging with build ID and latest

### 3. Deploy Stage
- ECR registry secret creation for Kubernetes
- Service account setup with ECR access
- Token replacement in Kubernetes manifests
- Sequential deployment of Kubernetes resources
- Health checks and rollout verification
- Ingress URL extraction

## Prerequisites

### Azure DevOps Setup
1. **Service Connections**:
   - `service_connect_aws_tf`: AWS service connection for Terraform
   - `aws_cli`: AWS CLI credentials (must have ECR permissions)
   - `KubernetesServiceConnection`: Kubernetes cluster connection

2. **Variable Groups** (Update in pipeline):
   - `ecrRegistry`: Your AWS ECR registry URI (format: 123456789012.dkr.ecr.region.amazonaws.com)
   - `AWS_ACCOUNT_ID`: Your AWS Account ID
   - Update EKS cluster name in AWS CLI tasks

3. **AWS IAM Permissions Required**:
   - ECR: `ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:GetDownloadUrlForLayer`, `ecr:BatchGetImage`
   - ECR: `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`, `ecr:PutImage`

### Required Azure DevOps Extensions
- Terraform extension
- AWS CLI extension
- Replace Tokens extension

### AWS ECR Repository Setup
Before running the pipeline, ensure your ECR repository exists:
```bash
# Create ECR repository
aws ecr create-repository --repository-name flask-static-app --region us-east-1

# Get ECR URI for pipeline configuration
aws ecr describe-repositories --repository-names flask-static-app --region us-east-1
```

## Deployment Instructions

### 1. Setup Prerequisites
```bash
# Update pipeline variables
ecrRegistry: '123456789012.dkr.ecr.us-east-1.amazonaws.com'
AWS_ACCOUNT_ID: '123456789012'

# Create ECR repository if it doesn't exist
aws ecr create-repository --repository-name flask-static-app --region us-east-1
```

### 2. Configure Service Connections
- Create AWS service connection in Azure DevOps with ECR permissions
- Configure Kubernetes service connection for EKS cluster
- Ensure AWS CLI credentials have ECR push/pull permissions

### 3. Run Pipeline
```bash
# Push changes to main branch to trigger pipeline
git add .
git commit -m "Add Flask application and deployment manifests"
git push origin main
```

### 4. Access Application
After successful deployment, the application will be available at the ALB URL:
```bash
# Get the application URL
kubectl get ingress flask-app-ingress -o jsonpath="{.status.loadBalancer.ingress[0].hostname}"
```

## Local Development

### Run Flask App Locally
```bash
cd src
pip install -r requirements.txt
python app.py
# Access at http://localhost:80
```

### Build Docker Image Locally
```bash
cd src
docker build -t flask-static-app .

# Test locally
docker run -p 8080:80 flask-static-app
# Access at http://localhost:8080

# Push to ECR (after AWS CLI login)
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com
docker tag flask-static-app:latest 123456789012.dkr.ecr.us-east-1.amazonaws.com/flask-static-app:latest
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/flask-static-app:latest
```

### Test Kubernetes Manifests
```bash
# Apply manifests to local cluster
kubectl apply -f manifests/
```

## Monitoring and Troubleshooting

### ECR Authentication Issues
```bash
# Check ECR login
aws ecr get-login-password --region us-east-1

# Verify ECR repository exists
aws ecr describe-repositories --repository-names flask-static-app

# Check ECR permissions
aws sts get-caller-identity
aws iam list-attached-user-policies --user-name your-username
```

### Check Deployment Status
```bash
kubectl get pods,svc,ingress -l app=flask-app
kubectl rollout status deployment/flask-app-deployment
```

### View Logs
```bash
kubectl logs -l app=flask-app -f
```

### Check Ingress
```bash
kubectl describe ingress flask-app-ingress
```

### Scaling
```bash
# Manual scaling
kubectl scale deployment flask-app-deployment --replicas=5

# Check HPA status
kubectl get hpa flask-app-hpa
```

## Security Features

- Non-root container user
- Resource limits and requests
- Health checks for reliability
- Pod Disruption Budget for availability
- ECR image pull secrets for secure container access
- Service account with minimal required permissions
- Network policies ready (can be added)

## Customization

### Updating the Application
1. Modify Flask app in `src/` directory
2. Update version in `manifests/configmap.yaml`
3. Push changes to trigger pipeline

### Scaling Configuration
- Modify replica count in `manifests/deployment.yaml`
- Adjust HPA settings in `manifests/hpa.yaml`
- Update resource limits as needed

### Custom Domain
- Update ingress annotations for custom domain
- Add SSL/TLS certificate configuration
- Configure Route53 or DNS provider

## Best Practices Implemented

✅ **Infrastructure as Code**: Terraform for AWS resources  
✅ **CI/CD Pipeline**: Automated build and deployment  
✅ **Container Security**: Non-root user, minimal base image  
✅ **Container Registry**: AWS ECR for secure image storage  
✅ **High Availability**: Multiple replicas, PDB  
✅ **Auto-scaling**: HPA based on resource utilization  
✅ **Health Monitoring**: Liveness and readiness probes  
✅ **Configuration Management**: ConfigMaps for environment variables  
✅ **Load Balancing**: AWS ALB with health checks  
✅ **Secret Management**: ECR authentication with Kubernetes secrets  

## Support

For issues and questions:
1. Check pipeline logs in Azure DevOps
2. Review Kubernetes events: `kubectl get events`
3. Check application logs: `kubectl logs -l app=flask-app`
4. Verify AWS resources in console