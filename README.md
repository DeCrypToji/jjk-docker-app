# JJK Docker App

> A Jujutsu Kaisen fan tribute site deployed end to end via a full DevSecOps pipeline — containerised with Docker, secured with Trivy and Hadolint, infrastructure provisioned with Terraform, served over HTTPS on a custom domain, and orchestrated with Kubernetes on both local minikube and AWS EKS.

![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)
![AWS ECS](https://img.shields.io/badge/AWS%20ECS-FF9900?style=flat&logo=amazonaws&logoColor=white)
![AWS EKS](https://img.shields.io/badge/AWS%20EKS-FF9900?style=flat&logo=amazonaws&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=flat&logo=kubernetes&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-2088FF?style=flat&logo=githubactions&logoColor=white)
![Trivy](https://img.shields.io/badge/Trivy-1904DA?style=flat&logo=aquasecurity&logoColor=white)
![HTTPS](https://img.shields.io/badge/HTTPS-secured-green?style=flat)

**Live:** https://jjk.decryptoji.com

---

## Architecture

```
Git push → GitHub Actions → Hadolint → Docker build → Trivy scan → ECR push
                                                                        │
                                                              ┌─────────┴──────────┐
                                                              │                    │
                                                         ECS Fargate            AWS EKS
                                                         (Terraform)          (eksctl/kubectl)
                                                              │                    │
                                                    Route53 → ALB → ACM    LoadBalancer Service
                                                              │                    │
                                                         ECS Task            K8s Pods (x2)
                                                         (nginx)              (nginx)
```

---

## CI/CD Pipeline

Every push to `main` triggers the following stages in order:

| Stage | Tool | Purpose |
|---|---|---|
| Lint | Hadolint | Validates Dockerfile against Docker best practices and CIS benchmark |
| Build | Docker | Builds image tagged with git commit SHA — no `latest` overwriting |
| Scan | Trivy | Blocks push on CRITICAL CVEs — shift-left security gate |
| Push | AWS ECR | Stores versioned image — lifecycle policy retains last 10 |

---

## Infrastructure (Terraform)

All AWS resources provisioned as code — single command to build or destroy:

```bash
terraform apply -var="ecr_image_uri=<ecr-uri>:<sha>"
terraform destroy
```

| Resource | Purpose |
|---|---|
| ECS Cluster | Logical grouping of Fargate resources |
| Task Definition | Container blueprint — image, CPU (256), memory (512MB), port 80 |
| ECS Service | Maintains desired task count, registers tasks into ALB target group |
| ALB | Receives traffic, terminates TLS, forwards to healthy tasks |
| Target Group | Health checks tasks every 30s, routes ALB traffic to healthy containers |
| HTTP Listener | Permanent 301 redirect — HTTP → HTTPS |
| HTTPS Listener | TLS termination via ACM certificate, forwards to target group |
| ACM Certificate | SSL/TLS for `jjk.decryptoji.com` — DNS validated via Route53 |
| Route53 A Record | Alias record pointing `jjk.decryptoji.com` to ALB |
| Security Group | Inbound ports 80 + 443 only — least privilege network access |
| ECR Lifecycle Policy | Retains last 10 images — cost and hygiene control |

---

## Kubernetes

The app was deployed to Kubernetes in two environments — local and cloud.

### Local (minikube)

```bash
minikube start --driver=docker
eval $(minikube docker-env)
docker build -t jjk-app:latest .
kubectl apply -f k8s-deployment.yaml
minikube service jjk-service --url
```

**Concepts validated locally:**
- Pod scheduling and self-healing — deleted pods replaced automatically
- Replica scaling — `kubectl scale deployment jjk-deployment --replicas=10` instant
- Rolling updates — zero downtime on config changes
- Namespaces — isolated `jjk-dev` environment alongside `default`
- Real time logging — `kubectl logs <pod> -f`

### Cloud (AWS EKS)

```bash
eksctl create cluster \
  --name jjk-cluster \
  --region eu-central-1 \
  --nodegroup-name jjk-nodes \
  --node-type t3.small \
  --nodes 2 \
  --managed

kubectl apply -f k8s-deployment.yaml
kubectl get service jjk-service
```

- 2 worker nodes (t3.small EC2) managed by AWS
- Image pulled directly from ECR via node IAM role
- Publicly exposed via AWS LoadBalancer service
- Same `kubectl` commands as minikube — zero context switching

### k8s-deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jjk-deployment
  labels:
    app: jjk
spec:
  replicas: 2
  selector:
    matchLabels:
      app: jjk
  template:
    metadata:
      labels:
        app: jjk
    spec:
      containers:
      - name: jjk-container
        image: 119750096239.dkr.ecr.eu-central-1.amazonaws.com/jjk-docker-app:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: jjk-service
spec:
  selector:
    app: jjk
  type: LoadBalancer
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
```

---

## Security

- **Shift-left** — Hadolint and Trivy gate the pipeline before any image reaches ECR
- **Least privilege** — dedicated IAM user, `ecsTaskExecutionRole` for task pulls, `AmazonEC2ContainerRegistryReadOnly` for EKS nodes
- **No hardcoded credentials** — AWS keys stored as GitHub Actions encrypted secrets
- **Image versioning** — SHA tagging ensures every build is uniquely traceable and rollback-ready
- **HTTPS enforced** — HTTP redirects to HTTPS via ALB, TLS terminated with ACM certificate
- **Minimal attack surface** — nginx:alpine base image, explicit OpenSSL and libexpat patches
- **Network isolation** — security group restricts inbound to ports 80 and 443 only

---

## CVE Handling

| CVE | Severity | Resolution |
|---|---|---|
| CVE-2024-45491 | CRITICAL | Patched — `apk upgrade libexpat` in Dockerfile |
| CVE-2026-31789 | CRITICAL | Patched — `apk upgrade openssl` in Dockerfile |
| Various libexpat | CRITICAL | No upstream patch available — documented in `.trivyignore` with risk acceptance |

---

## Key Debugging

| Issue | Root Cause | Resolution |
|---|---|---|
| 403 Forbidden | nginx running as `others`, file permissions `-rwxrwx---` | `chmod 644` in Dockerfile |
| Blank page | File wiped when exec-ing into running container | Baked fix into Dockerfile via `RUN` |
| ECR auth failure | `sudo docker push` ran as root, credentials on user | Added user to docker group, chained login and push with `&&` |
| Trivy blocking pipeline | CVEs in base nginx:alpine | Pinned to `nginx:1.27-alpine`, patched OpenSSL and libexpat |
| 503 from ALB | ECS service not registered to target group | Added `load_balancer` block and `depends_on` to ECS service in Terraform |
| ErrImageNeverPull on EKS | `imagePullPolicy: Never` left from minikube config | Removed policy, EKS pulls from ECR directly |
| EKS nodes cannot pull from ECR | Node IAM role missing ECR permissions | Added `AmazonEC2ContainerRegistryReadOnly` to node instance role |

---

## Stack

```
App           → HTML5 / CSS3 / JS / SVG — single file, no framework
Server        → nginx:1.27-alpine
Container     → Docker
Registry      → AWS ECR (eu-central-1)
Orchestration → AWS ECS Fargate + AWS EKS (Kubernetes)
IaC           → Terraform (AWS provider ~> 5.0)
K8s local     → minikube
K8s cloud     → AWS EKS (eksctl, t3.small nodes)
Pipeline      → GitHub Actions
Security      → Hadolint, Trivy, AWS IAM, ACM, Security Groups
DNS           → Route53 + Namecheap
TLS           → ALB + ACM
Environment   → Ubuntu 24 (VirtualBox), VS Code
```

---

## Project Completion

This project was built across multiple sessions as part of a deliberate transition from FTTP installation engineering into DevSecOps and cloud engineering. Every component was debugged and understood — not copied from a tutorial.

**Skills demonstrated:**
- Container build, scan and push pipeline with security gates
- Infrastructure as Code with full destroy/rebuild cycle
- Cloud container orchestration on ECS Fargate and EKS
- Kubernetes core concepts — pods, deployments, services, scaling, self-healing, namespaces
- TLS/HTTPS configuration end to end
- Real CVE remediation and risk-based security decisions

---

## What's Next

- [ ] Project 2 — enterprise-grade production environment:
  - Multi-environment pipeline (dev → staging → production)
  - EKS with IRSA, network policies, pod security standards
  - Full observability — Prometheus, Grafana, ELK Stack
  - GitOps with ArgoCD
  - Ansible configuration management
  - REST API with PostgreSQL backend
  - Advanced security — Falco, GuardDuty, WAF, OPA/Gatekeeper, Checkov
  - HashiCorp Vault / AWS Secrets Manager
  - Terraform modules with remote state

---

**DeCrypToji** — transitioning from network infrastructure into DevSecOps
- GitHub: [@DeCrypToji](https://github.com/DeCrypToji)
- LinkedIn: [Janali Miller-Reid](https://www.linkedin.com/in/janali-miller-reid-0835101a2/)

*Fan tribute — Jujutsu Kaisen © Gege Akutami / Shueisha*
