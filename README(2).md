# JJK Docker App 🔵
> A Jujutsu Kaisen fan tribute site containerised with Docker and nginx, pushed to AWS ECR as part of my DevSecOps learning journey.

![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)
![nginx](https://img.shields.io/badge/nginx-009639?style=flat&logo=nginx&logoColor=white)
![AWS ECR](https://img.shields.io/badge/AWS%20ECR-FF9900?style=flat&logo=amazonaws&logoColor=white)
![HTML5](https://img.shields.io/badge/HTML5-E34F26?style=flat&logo=html5&logoColor=white)

---

## What this project does

A fully static, single-file web app themed around the anime Jujutsu Kaisen. Features six character cards with hand-crafted SVG silhouettes, animated cursed energy effects, domain expansion breakdowns, and responsive layout — all served via nginx inside a Docker container and stored as an image in AWS ECR.

---

## Architecture

```
index.html (static site)
     │
     ▼
Dockerfile
     │  docker build
     ▼
Docker Image (nginx:alpine)
     │
     ├──▶ docker run → localhost:8080 (local testing)
     │
     │  docker push
     ▼
AWS ECR (Elastic Container Registry)
119750096239.dkr.ecr.eu-central-1.amazonaws.com/jjk-docker-app:latest
```

---

## Technologies used

| Tool | Purpose |
|---|---|
| HTML5 / CSS3 / JavaScript | Static web app — single file, no frameworks |
| SVG | Hand-crafted character illustrations, no external images |
| Docker | Containerising the app with nginx:alpine base image |
| nginx | Serving the static site inside the container |
| AWS ECR | Storing and versioning the Docker image in the cloud |
| AWS CLI | Authenticating and pushing to ECR from the terminal |
| Ubuntu (VirtualBox VM) | Development environment |

---

## Project structure

```
jjk-docker-app/
├── index.html        # Full site — HTML, CSS, JS and SVG art in one file
├── Dockerfile        # Build instructions for the nginx container
└── README.md
```

---

## Dockerfile

```dockerfile
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
RUN chmod 644 /usr/share/nginx/html/index.html
EXPOSE 80
```

---

## How to run locally

**Prerequisites:** Docker installed and running

```bash
# Clone the repo
git clone https://github.com/DeCrypToji/jjk-docker-app.git
cd jjk-docker-app

# Build the image
docker build -t jjk-app .

# Run the container
docker run -p 8080:80 jjk-app
```

Then open your browser at `http://localhost:8080`

---

## Pushing to AWS ECR

```bash
# Create the repository (first time only)
aws ecr create-repository --repository-name jjk-docker-app --region eu-central-1

# Authenticate Docker to ECR
aws ecr get-login-password --region eu-central-1 | docker login \
  --username AWS \
  --password-stdin 119750096239.dkr.ecr.eu-central-1.amazonaws.com

# Tag the image
docker tag jjk-app:latest \
  119750096239.dkr.ecr.eu-central-1.amazonaws.com/jjk-docker-app:latest

# Push to ECR
docker push \
  119750096239.dkr.ecr.eu-central-1.amazonaws.com/jjk-docker-app:latest
```

---

## Problems I hit and how I solved them

This section documents the real debugging process — not just the happy path.

**Issue 1 — Default nginx page showing instead of my site**
After running the container the default nginx welcome page appeared instead of my HTML.
**Root cause:** The file was not named `index.html` when copied into the container.
**Fix:** Ensured the filename matched exactly in both the project directory and the `COPY` command in the Dockerfile.

**Issue 2 — 403 Forbidden**
nginx could locate the file but returned a 403 error.
**Root cause:** File permissions were set to `-rwxrwx---`, meaning the `others` group (which nginx runs as) had zero read permissions.
**Fix:** Added `RUN chmod 644` to the Dockerfile, giving nginx read access while keeping write access restricted to the owner — following least privilege principles from my Security+ studies.

**Issue 3 — Blank page after permission fix**
The site loaded but rendered completely blank.
**Root cause:** The `index.html` file was wiped when manually exec-ing into the running container to change permissions. Changes made inside a running container are not persisted in the image.
**Fix:** Rebuilt the image cleanly from scratch with `chmod` baked into the Dockerfile via `RUN`, removing the need to manually exec into the container.

**Issue 4 — ECR push authorization failure**
`docker push` was returning `no basic auth credentials` despite having configured AWS CLI.
**Root cause:** Running `sudo docker push` runs Docker as root, but AWS credentials were saved to the normal user's `~/.aws/credentials`. Root had no credentials configured.
**Fix:** Added user to the docker group with `sudo usermod -aG docker $USER`, applied with `sudo chmod 666 /var/run/docker.sock`, then ran the ECR login and push in a single chained command using `&&` to keep the same session.

**Issue 5 — ECR repository does not exist**
Push failed because the ECR repository hadn't been created yet.
**Fix:** Created the repository via CLI with `aws ecr create-repository --repository-name jjk-docker-app --region eu-central-1` then re-ran the push.

---

## What I learned

- How Docker images and containers differ — the image is immutable, the container is the running instance
- Why changes made inside a running container don't persist and how to bake configuration correctly into the Dockerfile
- How Linux file permissions (`chmod 644`) affect what processes can read files — directly relevant to the principle of least privilege
- Why mixing `sudo` and user-level credentials causes authentication failures and how Linux user and group permissions underpin this
- The full ECR workflow end to end: create repo → build → tag → authenticate → push
- How to chain commands with `&&` to keep session context between steps
- How to debug containerised apps using `docker exec` and `docker logs`

---

## Background

This project was built as part of my transition from FTTP installation engineering into DevSecOps and cloud engineering. I hold CompTIA A+ and Security+ certifications and am currently working toward AWS Cloud Practitioner.

The goal was to take a real static site, containerise it properly, debug the issues that came up in a real environment, and push it to a cloud registry — mirroring a real-world deployment workflow.

Coming from a background in physical network infrastructure, this project bridges my existing knowledge of uptime, fault diagnosis, and working to standards with hands-on cloud and container skills.

---

## What's next

- [ ] Set up a GitHub Actions pipeline to build and push to ECR automatically on every commit
- [ ] Deploy the container to AWS ECS so it runs in the cloud, not just locally
- [ ] Add HTTPS via an nginx config update
- [ ] Scan the image for vulnerabilities with Trivy before the push step
- [ ] Store AWS credentials securely using a credential helper rather than plain text

---

## Author

**DeCrypToji** — transitioning from network infrastructure into DevSecOps
- GitHub: [@DeCrypToji](https://github.com/DeCrypToji)

---

*Fan tribute — Jujutsu Kaisen © Gege Akutami / Shueisha*
