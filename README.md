# Learn Terraform – Provision an EKS Cluster & Deploy a Flask App

This repository extends HashiCorp's "Provision an EKS Cluster" tutorial with a production-style Azure DevOps pipeline that:

1. Provisions the underlying AWS infrastructure (VPC, EKS, node groups, IAM roles) with Terraform.
2. Builds and pushes a containerized Flask web application to Amazon ECR.
3. Deploys the Flask workload onto the EKS cluster with Kubernetes manifests and health checks.

Use it as a reference implementation for standing up an end-to-end CI/CD pipeline targeting AWS from Azure DevOps.

---

## 🔧 Prerequisites

| Requirement | Notes |
| --- | --- |
| **AWS account** | Permissions to create VPC, EKS, IAM, ECR, ALB, CloudWatch resources. |
| **Azure DevOps project** | With [Azure Pipelines](https://learn.microsoft.com/azure/devops/pipelines/) enabled. |
| **Service connections** |<ul><li>`service_connect_aws_tf` – AWS service connection with access key/secret for Terraform</li><li>`aws_cli` – AWS service connection for CLI/AWS Shell tasks</li><li>`KubernetesServiceConnection` – Kubernetes connection (or use AWS CLI to refresh kubeconfig)</li><li>`aws-ecr-connection` – Optional; use if you rely on ECR tasks</li></ul>|
| **Tooling (local workflows)** | Terraform ≥ 1.7, kubectl, AWS CLI, Docker (for manual testing). |
| **GitHub access** | Clone or fork this repository. |

> ⚠️ **Authorization tip:** After creating service connections, open the pipeline in Azure DevOps and click "Authorize Resources" so each connection is available at runtime.

---

## 📦 Repository Structure

```
.
├── azure-pipelines-iac-tf-eks.yml   # Azure DevOps multi-stage pipeline
├── main.tf / variables.tf / outputs.tf  # Terraform configuration for VPC + EKS
├── terraform.tf                      # Terraform backend/provider settings
├── manifests/                        # Kubernetes manifests (deployment, service, ingress, HPA, etc.)
├── src/                              # Flask application source & Dockerfile
├── aws-iam-ecr-policy.json           # Sample IAM policy snippet for ECR access
└── README.md                         # This guide
```

---

## 🛠️ Azure Pipeline Overview

`azure-pipelines-iac-tf-eks.yml` defines three stages:

1. **Infrastructure**
	- Installs Terraform and performs `init`, `plan`, `apply` using the `service_connect_aws_tf` connection.
	- Captures the EKS cluster name for downstream stages.
	- Ensures the target ECR repository exists (creates it and applies lifecycle policies if missing).

2. **Build**
	- Verifies Docker context, builds the Flask image, tags it with `$(Build.BuildId)` and `latest`.
	- Authenticates against ECR and pushes both tags.
	- Confirms pushed image visibility via `aws ecr list-images`.

3. **Deploy**
	- Reuses Terraform outputs to reconfigure kubeconfig for the newly created cluster.
	- Applies Kubernetes manifests (service account, config map, deployment, service, ingress, HPA, PDB).
	- Patches the service account with the ECR pull secret and waits for a successful rollout.
	- On failure, automatically gathers diagnostics (`kubectl describe`, pod logs, recent events).

Key pipeline variables are defined at the top of the YAML (registry URI, repository name, namespace, etc.). Update them to match your environment.

---

## 🚀 Getting Started

### 1. Fork & Clone

```powershell
git clone https://github.com/<your-org>/learn-terraform-provision-eks-cluster.git
cd learn-terraform-provision-eks-cluster
```

### 2. Customize Configuration

- **ECR registry URI** – Update `variables.ecrRegistry` in the pipeline or store it as a pipeline variable secret.
- **AWS backend bucket** – The Terraform backend expects a bucket named `tf-state-file-4-az-pipeline-eks-test`. Adjust `backendAWSBucketName` if you use something different.
- **Application manifests** – Edit files under `manifests/` to change image names, resource limits, ingress rules, etc.

### 3. Configure Azure DevOps

1. Create or import the pipeline (Azure DevOps → Pipelines → New pipeline → Existing YAML file → select `azure-pipelines-iac-tf-eks.yml`).
2. Provide required pipeline variables if you prefer not to hardcode them in YAML (e.g., `awsRegion`, `imageRepository`, `namespace`).
3. Authorize all referenced service connections.

### 4. Run the Pipeline

Trigger the pipeline manually or by pushing to `main`. Watch the logs for each stage. On success you should see:

- Terraform outputs showing the EKS cluster and load balancer endpoint.
- Docker image pushed to ECR with the build ID tag.
- Kubernetes rollout finishing with `Deployment successfully rolled out`.

### 5. Access the Application

After rollout, retrieve the ingress host:

```bash
kubectl get ingress flask-app-ingress -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Browse to `http://<hostname>` (or `https://` if you configured TLS) to view the Flask app.

---

## 🧪 Local Development (Optional)

1. Build the container locally:

	```bash
	docker build -t flask-static-app:dev -f src/Dockerfile src/
	```

2. Run tests or lint your Flask code as needed.

3. Execute Terraform locally if you prefer manual provisioning:

	```bash
	terraform init
	terraform apply
	```

	Remember to set the same backend config or comment out the remote backend if you want local state.

---

## 🧹 Cleanup

To tear everything down:

```bash
terraform destroy
```

Also delete the ECR repository (or rely on lifecycle policies) and clean up any residual CloudWatch logs or load balancers created by the ingress controller.

---

## 🛠️ Troubleshooting

| Symptom | Likely Cause | Resolution |
| --- | --- | --- |
| `InvalidClientTokenId` during Terraform init | AWS credentials in `service_connect_aws_tf` are expired or unauthorized. | Rotate access key/secret, re-authorize the service connection, rerun. |
| `Provided region_name '$(awsRegion)' doesn't match a supported format` | Pipeline variable not set or mis-cased. | Ensure `awsRegion` variable is defined (case-sensitive) and matches `us-east-1` or your target region. |
| Terraform task complains about missing service connection | Service connection not authorized for the pipeline. | Open the pipeline in Azure DevOps, click "View YAML", then "Authorize resources". |
| Pods stuck `ImagePullBackOff` | Image tag mismatch or secret missing. | Confirm the deployment manifest uses the pushed tag and that `ecr-registry-secret` exists in the namespace. |
| Readiness probe failures | Flask container not serving on expected port/path. | Inspect pod logs (pipeline collects these automatically on failure) and adjust readiness probe or app configuration. |

---

## 📚 Further Reading

- [Terraform AWS EKS Module](https://github.com/terraform-aws-modules/terraform-aws-eks)
- [Amazon EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Azure Pipelines for multi-stage deployments](https://learn.microsoft.com/azure/devops/pipelines/process/stages)
- [Flask deployment best practices](https://flask.palletsprojects.com/)

---

## 📝 License

This project inherits the license defined in [`LICENSE`](./LICENSE). Review before reusing or distributing.

---

Happy shipping! If you extend the pipeline (e.g., add automated tests, blue/green deployments, or observability hooks), contributions and ideas are welcome.
