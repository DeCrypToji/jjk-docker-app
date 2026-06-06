# JJK Docker App 🔵
> A Jujutsu Kaisen fan tribute site containerised with Docker and nginx, with a full DevSecOps CI/CD pipeline — built as part of my transition from network infrastructure into cloud engineering.

![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)
![nginx](https://img.shields.io/badge/nginx-009639?style=flat&logo=nginx&logoColor=white)
![AWS ECR](https://img.shields.io/badge/AWS%20ECR-FF9900?style=flat&logo=amazonaws&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-2088FF?style=flat&logo=githubactions&logoColor=white)
![Trivy](https://img.shields.io/badge/Trivy-1904DA?style=flat&logo=aquasecurity&logoColor=white)
![Hadolint](https://img.shields.io/badge/Hadolint-000000?style=flat&logo=docker&logoColor=white)
![HTML5](https://img.shields.io/badge/HTML5-E34F26?style=flat&logo=html5&logoColor=white)

---

## What this project does

A fully static, single-file web app themed around the anime Jujutsu Kaisen. Features six character cards with hand-crafted SVG silhouettes, animated cursed energy effects, domain expansion breakdowns, and responsive layout — all served via nginx inside a Docker container.

Every commit to `main` automatically triggers a GitHub Actions pipeline that lints the Dockerfile, builds the image, scans for vulnerabilities, and pushes a uniquely versioned image to AWS ECR. No manual intervention required after the initial push.

---

## Pipeline architecture

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
    119750096239.dkr.ecr.eu-central-1.amazonaws.com
    /jjk-docker-app:<git-sha>
```

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
| AWS IAM | Least privilege access — dedicated user with ECR permissions only |
| ECR Lifecycle Policy | Automated image retention — keeps last 10 images, deletes older ones |
| AWS CLI | Infrastructure management from the terminal |
| Ubuntu (VirtualBox VM) | Development environment |

---

## Project structure

```
jjk-docker-app/
├── .github/
│   └── workflows/
│       └── deploy.yml          # Full CI/CD pipeline definition
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
- `nginx:1.27-alpine` — pinned to a specific version for reproducibility. Alpine is used over full Debian/Ubuntu because it is a minimal OS (~5MB) with a significantly smaller attack surface
- `apk upgrade openssl libexpat` — explicitly patches known CVEs in these packages during the build rather than relying on the base image to be up to date
- `chmod 644` — applies least privilege to the HTML file. nginx requires read access (`4`) but not write (`2`) or execute (`1`). `644` gives owner read/write, group and others read only

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

## Key pipeline decisions

**Why Hadolint runs before the build:**
Validating the Dockerfile before building avoids wasting compute time building a non-compliant or broken image. Catch issues as early as possible — shift-left applied to infrastructure code, not just application code.

**Why Trivy runs before the push:**
A vulnerable image should never reach the registry. By scanning between build and push, CRITICAL CVEs block the pipeline before the image is stored, preventing vulnerable artefacts from ever being available for deployment.

**Why images are tagged with git SHA instead of `latest`:**
Tagging with `latest` overwrites the previous image on every push, making rollbacks impossible. The git commit SHA creates a unique, immutable tag for every build — every image in ECR is traceable back to the exact commit that produced it. This is essential for Kubernetes rolling updates and incident rollback in production.

**Why a dedicated IAM user is used instead of root:**
Root access keys are a critical security risk — root has unrestricted access to the entire AWS account. A dedicated IAM user with only `AmazonEC2ContainerRegistryFullAccess` means a compromised key can only affect ECR, nothing else. Least privilege principle applied directly from CompTIA Security+ studies.

---

## ECR lifecycle policy

Without a lifecycle policy, every push creates a new SHA-tagged image that accumulates indefinitely, increasing storage costs over time.

The following policy is applied to the ECR repository — automatically expiring images beyond the most recent 10:

```json
{
  "rules": [{
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
  }]
}
```

Applied via CLI:
```bash
aws ecr put-lifecycle-policy \
  --repository-name jjk-docker-app \
  --lifecycle-policy-text file://ecr-lifecycle-policy.json
```

---

## Security — CVE handling

Trivy scans the image on every pipeline run. The pipeline blocks any push where CRITICAL vulnerabilities are found with no documented justification.

| CVE | Severity | Description | Resolution |
|---|---|---|---|
| CVE-2024-45491 | CRITICAL | libexpat integer overflow in `dtdCopy` function — potential arbitrary code execution with CVSS score 9.8 | Patched via `apk upgrade libexpat` in Dockerfile |
| CVE-2026-31789 | CRITICAL | OpenSSL heap buffer overflow on 32-bit systems | Patched via `apk upgrade openssl` in Dockerfile |
| Various libexpat | CRITICAL | Additional libexpat CVEs with no upstream patch available at time of build | Added to `.trivyignore` with documented risk acceptance |

**CVE management approach:**
When no patch exists, blocking the pipeline indefinitely is not a viable production strategy. The `.trivyignore` file records explicit risk acceptance decisions — in a production environment each entry would require security team sign-off with a target remediation date. This mirrors real-world vulnerability management processes where delivery and security must be balanced pragmatically.

---

## Security principles applied

| Principle | How it was applied |
|---|---|
| Shift-left security | Hadolint and Trivy run in the pipeline before any image reaches ECR |
| Least privilege | Dedicated IAM user with ECR-only permissions. `chmod 644` on nginx files |
| No hardcoded credentials | AWS keys stored as GitHub Actions encrypted secrets, never in code |
| Image immutability | SHA tagging ensures every image is uniquely versioned and traceable |
| Cost and hygiene control | ECR lifecycle policy prevents unbounded image accumulation |
| Risk-based CVE management | CRITICAL CVEs patched where possible, documented where no patch exists |
| Minimal attack surface | Alpine Linux base image (~5MB) used over full OS distributions |

---

## Problems encountered and resolved

**Issue 1 — Default nginx page showing instead of the site**
Root cause: File not named `index.html` in the container.
Resolution: Ensured filename matched exactly in both project directory and Dockerfile `COPY` command.

**Issue 2 — 403 Forbidden**
Root cause: File permissions set to `-rwxrwx---`. nginx runs as `others` which had zero read permissions.
Resolution: `RUN chmod 644` added to Dockerfile — least privilege applied, nginx gets read access only.

**Issue 3 — Blank page after permission fix**
Root cause: `index.html` wiped when manually exec-ing into the running container. Changes inside a running container are not persisted in the image.
Resolution: Rebuilt image cleanly. `chmod` baked into Dockerfile via `RUN` — no manual exec required.

**Issue 4 — ECR push authorization failure**
Root cause: `sudo docker push` runs as root but AWS credentials saved to normal user's `~/.aws/credentials`. Root had no credentials configured — mixing sudo with user-level credential contexts causes subtle authentication failures.
Resolution: Added user to docker group. Ran ECR login and push in single `&&` chained command to maintain session context.

**Issue 5 — ECR repository does not exist**
Resolution: Created repository via CLI before pushing.

**Issue 6 — GitHub Actions credential mismatch**
Root cause: Outdated root access keys stored in GitHub secrets after rotating to dedicated IAM user.
Resolution: Updated both GitHub Actions secrets with new IAM user credentials.

**Issue 7 — Trivy blocking pipeline on CRITICAL CVEs**
Root cause: Base `nginx:alpine` image contained known vulnerabilities in OpenSSL and libexpat.
Resolution: Pinned to `nginx:1.27-alpine`, added `apk upgrade openssl libexpat` to Dockerfile. Remaining unpatched CVEs added to `.trivyignore` with documented justification.

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

## Background

Built as part of my transition from FTTP installation engineering into DevSecOps and cloud engineering. I hold CompTIA A+ and Security+ certifications and am currently working toward AWS Cloud Practitioner.

My background in physical network infrastructure brings real-world understanding of uptime pressure, fault diagnosis under stress, and compliance frameworks — applied here through security-first decision making at every stage of the pipeline.

---

## What's next

- [ ] Deploy to AWS ECS — run the container in the cloud
- [ ] Provision infrastructure with Terraform — full IaC, destroy and rebuild cycle
- [ ] Add HTTPS via ALB and AWS Certificate Manager
- [ ] Add DAST scanning to the pipeline
- [ ] Kubernetes deployment on AWS EKS
- [ ] AWS Cloud Practitioner certification
- [ ] Project 2 — full enterprise-grade production environment with multi-environment pipeline, monitoring and GitOps

---

## Author

**DeCrypToji** — transitioning from network infrastructure into DevSecOps
- GitHub: [@DeCrypToji](https://github.com/DeCrypToji)
- LinkedIn: [linkedin.com/in/your-profile](https://linkedin.com)

---

*Fan tribute — Jujutsu Kaisen © Gege Akutami / Shueisha*
