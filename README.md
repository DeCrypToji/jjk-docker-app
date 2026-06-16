# JJK Docker App 🔵
> A Jujutsu Kaisen fan tribute site containerised with Docker and nginx, with a full DevSecOps CI/CD pipeline and live deployment to AWS ECS Fargate — built as part of my transition from network infrastructure into cloud engineering.

![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)
![nginx](https://img.shields.io/badge/nginx-009639?style=flat&logo=nginx&logoColor=white)
![AWS ECR](https://img.shields.io/badge/AWS%20ECR-FF9900?style=flat&logo=amazonaws&logoColor=white)
![AWS ECS](https://img.shields.io/badge/AWS%20ECS-FF9900?style=flat&logo=amazonaws&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-2088FF?style=flat&logo=githubactions&logoColor=white)
![Trivy](https://img.shields.io/badge/Trivy-1904DA?style=flat&logo=aquasecurity&logoColor=white)
![Hadolint](https://img.shields.io/badge/Hadolint-000000?style=flat&logo=docker&logoColor=white)
![HTML5](https://img.shields.io/badge/HTML5-E34F26?style=flat&logo=html5&logoColor=white)

---

## What this project does

A fully static, single-file web app themed around the anime Jujutsu Kaisen. Features six character cards with hand-crafted SVG silhouettes, animated cursed energy effects, domain expansion breakdowns, and responsive layout — all served via nginx inside a Docker container.

Every commit to `main` automatically triggers a GitHub Actions pipeline that lints the Dockerfile, builds the image, scans for vulnerabilities, and pushes a uniquely versioned image to AWS ECR. The image is then deployed and served publicly via AWS ECS Fargate — no manual intervention required after the initial push.

---

## Full architecture

```
Developer pushes code to GitHub (main branch)
                │
                ▼
    ┌───────────────────────┐
    │   GitHub Actions      │
    │   Ubuntu Runner       │
    └───────────────────────┘
                │
                ▼
    ┌───────────────────────┐
    │  Checkout code        │  Pulls repo onto runner
    └───────────────────────┘
                │
                ▼
    ┌───────────────────────┐
    │  Configure AWS        │  Authenticates via IAM
    │  credentials          │  using GitHub secrets
    └───────────────────────┘
                │
                ▼
    ┌───────────────────────┐
    │  Login to ECR         │  Docker authenticated
    └───────────────────────┘
                │
                ▼
    ┌───────────────────────┐
    │  Hadolint             │  Lints Dockerfile against
    │  Dockerfile lint      │  Docker best practices
    └───────────────────────┘  and CIS Docker Benchmark
                │
          FAIL ─┤─ PASS
                │
                ▼
    ┌───────────────────────┐
    │  Docker build         │  Builds image tagged with
    │                       │  unique git commit SHA
    └───────────────────────┘
                │
                ▼
    ┌───────────────────────┐
    │  Trivy CVE scan       │  Scans image for known
    │  (security gate)      │  vulnerabilities
    └───────────────────────┘
                │
          FAIL ─┤─ PASS
    (CRITICAL   │
     CVEs found)│
                ▼
    ┌───────────────────────┐
    │  Push to AWS ECR      │  Image stored with SHA tag
    │                       │  for full version control
    └───────────────────────┘
                │
                ▼
    ┌─────────────────────────────────────┐
    │         AWS ECS Fargate             │
    │                                     │
    │  Cluster: jjk-cluster               │
    │  Service: jjk-service               │
    │  Task:    jjk-task                  │
    │                                     │
    │  Pulls image from ECR               │
    │  Runs nginx container               │
    │  Exposes port 80 publicly           │
    │  Auto-restarts if container crashes │
    └─────────────────────────────────────┘
                │
                ▼
         Public internet 🌍
```

---

## AWS infrastructure

| Resource | Name | Purpose |
|---|---|---|
| ECR Repository | `jjk-docker-app` | Stores versioned Docker images |
| ECS Cluster | `jjk-cluster` | Logical grouping of Fargate resources |
| Task Definition | `jjk-task` | Blueprint — defines image, CPU, memory, ports |
| ECS Service | `jjk-service` | Ensures task stays running, handles restarts |
| Security Group | `jjk-sg` | Allows inbound HTTP on port 80 from anywhere |
| IAM Role | `ecsTaskExecutionRole` | Allows ECS to pull from ECR and write logs |
| VPC | Default VPC | Network boundary — public subnets used |
| ECR Lifecycle Policy | Keep last 10 | Automatically expires old images to control cost |

---

## Technologies used

| Tool | Purpose |
|---|---|
| HTML5 / CSS3 / JavaScript | Static web app — single file, no frameworks |
| SVG | Hand-crafted character illustrations, no external images |
| Docker | Containerising the app with nginx:alpine base image |
| nginx | Serving the static site inside the container |
| GitHub Actions | CI/CD pipeline — automated lint, build, scan and push |
| Hadolint | Dockerfile static analysis — best practices and CIS benchmark |
| Trivy | Container image CVE scanning — shift-left security gate |
| AWS ECR | Storing and versioning Docker images in the cloud |
| AWS ECS Fargate | Serverless container orchestration — runs and manages containers |
| AWS IAM | Least privilege access — dedicated user with scoped permissions |
| AWS VPC | Network isolation — public subnets for container access |
| ECR Lifecycle Policy | Automated image retention management |
| AWS CLI | Infrastructure management from the terminal |
| Ubuntu (VirtualBox VM) | Development environment |

---

## Project structure

```
jjk-docker-app/
├── .github/
│   └── workflows/
│       └── deploy.yml          # GitHub Actions CI/CD pipeline
├── .trivyignore                # Documented CVE risk acceptances
├── index.html                  # Complete site — HTML, CSS, JS, SVG
├── Dockerfile                  # Container build instructions
└── README.md
```

---

## Dockerfile

```dockerfile
FROM nginx:1.27-alpine
RUN apk update && apk upgrade openssl libexpat
COPY index.html /usr/share/nginx/html/index.html
RUN chmod 644 /usr/share/nginx/html/index.html
EXPOSE 80
```

**Dockerfile decisions explained:**
- `nginx:1.27-alpine` — pinned to a specific version for reproducibility. Alpine used over full Debian/Ubuntu for minimal attack surface (~5MB vs ~200MB)
- `apk upgrade openssl libexpat` — explicitly patches known CVEs during build rather than relying on base image to be current
- `chmod 644` — least privilege applied. nginx requires read access only, not write or execute

---

## CI/CD Pipeline — deploy.yml

```yaml
name: Build and Push to ECR

on:
  push:
    branches:
      - main

jobs:
  build-and-push:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: eu-central-1

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1

      - name: Lint Dockerfile with Hadolint
        uses: hadolint/hadolint-action@v3.1.0
        with:
          dockerfile: Dockerfile

      - name: Build image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: jjk-docker-app
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .

      - name: Scan image with Trivy
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ steps.login-ecr.outputs.registry }}/jjk-docker-app:${{ github.sha }}
          format: table
          exit-code: 1
          severity: CRITICAL

      - name: Push image to ECR
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: jjk-docker-app
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
```

---

## ECS Fargate deployment

**Why Fargate over EC2:**
Fargate is serverless — AWS manages the underlying infrastructure, OS patching and scaling. This removes operational overhead and allows focus on the application and pipeline rather than server management. EC2 will be introduced in project 2 for workloads requiring more granular control.

**ECS concepts explained:**

```
Cluster — the logical boundary housing all ECS resources
    │
Task Definition — blueprint defining image, CPU, memory, ports, IAM role
    │
Task — the running instance of the task definition (the actual container)
    │
Service — ensures the desired number of tasks are always running
          auto-restarts crashed tasks, handles rolling deployments
```

**Networking:**
- Deployed into default VPC public subnets
- Security group `jjk-sg` allows inbound HTTP port 80 from `0.0.0.0/0`
- Public IP assigned to task for internet accessibility
- In production: private subnets with ALB in front, HTTPS via ACM

---

## Key pipeline decisions

**Why Hadolint runs before the build:**
Validating the Dockerfile before building avoids wasting compute time on a non-compliant image. Shift-left applied to infrastructure code.

**Why Trivy runs before the push:**
A vulnerable image should never reach the registry. CRITICAL CVEs block the pipeline before the image is stored.

**Why SHA tagging instead of `latest`:**
Every image is uniquely versioned and traceable back to the exact commit. Essential for rollbacks and Kubernetes rolling updates in production.

**Why Fargate:**
Serverless — no EC2 instance management, OS patching or capacity planning. AWS handles the infrastructure, the pipeline handles the delivery.

**Why a dedicated IAM user:**
Root access keys are a critical security risk. Least privilege applied — the IAM user has only the permissions required for ECR and ECS operations.

---

## Security principles applied

| Principle | How it was applied |
|---|---|
| Shift-left security | Hadolint and Trivy run before build and push respectively |
| Least privilege | Dedicated IAM user, scoped policies, `chmod 644` on files |
| No hardcoded credentials | AWS keys stored as GitHub Actions encrypted secrets |
| Image immutability | SHA tagging — every image uniquely versioned and traceable |
| Cost and hygiene control | ECR lifecycle policy — keeps last 10 images only |
| Risk-based CVE management | CRITICAL CVEs patched where possible, documented where not |
| Minimal attack surface | Alpine Linux base image, explicit package upgrades |
| Network segmentation | Security group restricts inbound to port 80 only |

---

## Security — CVE handling

| CVE | Severity | Description | Resolution |
|---|---|---|---|
| CVE-2024-45491 | CRITICAL | libexpat integer overflow — potential arbitrary code execution (CVSS 9.8) | Patched via `apk upgrade libexpat` |
| CVE-2026-31789 | CRITICAL | OpenSSL heap buffer overflow on 32-bit systems | Patched via `apk upgrade openssl` |
| Various libexpat | CRITICAL | Additional libexpat CVEs with no upstream patch at time of build | Added to `.trivyignore` with documented risk acceptance |

---

## Problems encountered and resolved

**Issue 1 — Default nginx page showing**
Root cause: File not named `index.html`. Fix: matched filename in Dockerfile `COPY` command.

**Issue 2 — 403 Forbidden**
Root cause: Permissions `-rwxrwx---`, nginx as `others` had no read access. Fix: `chmod 644` in Dockerfile.

**Issue 3 — Blank page**
Root cause: File wiped when exec-ing into running container. Fix: baked `chmod` into Dockerfile via `RUN`.

**Issue 4 — ECR push authorization failure**
Root cause: `sudo docker push` ran as root, credentials saved to normal user. Fix: added user to docker group, chained login and push with `&&`.

**Issue 5 — ECR repository does not exist**
Fix: `aws ecr create-repository` before pushing.

**Issue 6 — GitHub Actions credential mismatch**
Root cause: Outdated root keys in GitHub secrets after rotating to IAM user. Fix: updated secrets.

**Issue 7 — Trivy blocking on CRITICAL CVEs**
Root cause: Base image vulnerabilities in OpenSSL and libexpat. Fix: pinned nginx version, explicit package upgrades, `.trivyignore` for unpatched CVEs.

**Issue 8 — ECS task failing to pull image**
Root cause: `ecsTaskExecutionRole` needed to be attached to task definition to grant ECR pull permissions. Fix: selected existing execution role in task definition configuration.

---

## How to run locally

```bash
git clone https://github.com/DeCrypToji/jjk-docker-app.git
cd jjk-docker-app
docker build -t jjk-app .
docker run -p 8080:80 jjk-app
```

Open `http://localhost:8080`

---

## Cost management

- ECS Fargate tasks incur charges while running — stop the service when not in use
- Set desired task count to `0` in the ECS service to stop without deleting infrastructure
- ECR lifecycle policy keeps storage costs minimal — last 10 images retained only
- AWS billing alert set at $10 to catch unexpected charges early
- Next iteration will provision all infrastructure via Terraform enabling single command teardown

---

## Background

Built as part of my transition from FTTP installation engineering into DevSecOps and cloud engineering. I hold CompTIA A+ and Security+ certifications and am currently working toward AWS Cloud Practitioner.

My background in physical network infrastructure brings real-world understanding of uptime pressure, fault diagnosis under stress, and compliance frameworks — applied here through security-first decision making at every stage of the pipeline.

---

## What's next

- [ ] Provision all infrastructure with Terraform — full IaC teardown and rebuild
- [ ] Add HTTPS via ALB and AWS Certificate Manager
- [ ] Add Route53 custom domain
- [ ] Add DAST scanning to pipeline
- [ ] Kubernetes deployment on AWS EKS
- [ ] AWS Cloud Practitioner certification
- [ ] Project 2 — enterprise-grade production environment with multi-environment pipeline, Kubernetes, Prometheus/Grafana monitoring, ArgoCD GitOps, Ansible and a backend API with database

---

## Author

**DeCrypToji** — transitioning from network infrastructure into DevSecOps
- GitHub: [@DeCrypToji](https://github.com/DeCrypToji)
- LinkedIn: https://www.linkedin.com/in/janali-miller-reid-0835101a2/

---

*Fan tribute — Jujutsu Kaisen © Gege Akutami / Shueisha*
