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
# Authenticate Docker to ECR
aws ecr get-login-password --region <your-region> | docker login \
  --username AWS \
  --password-stdin <account-id>.dkr.ecr.<your-region>.amazonaws.com

# Tag the image
docker tag jjk-app:latest \
  <account-id>.dkr.ecr.<your-region>.amazonaws.com/jjk-docker-app:latest

# Push to ECR
docker push \
  <account-id>.dkr.ecr.<your-region>.amazonaws.com/jjk-docker-app:latest
```

---

## Problems I hit and how I solved them

This section documents the real debugging process — not just the happy path.

**Issue 1 — Default nginx page showing instead of my site**
After running the container, the default nginx welcome page appeared instead of my HTML file.
**Root cause:** The file was not named `index.html` when copied into the container.
**Fix:** Ensured the filename matched exactly in both the project directory and the `COPY` command in the Dockerfile.

**Issue 2 — 403 Forbidden**
nginx could locate the file but was returning a 403 error.
**Root cause:** File permissions were set to `-rwxrwx---`, meaning the `others` group (which nginx runs as) had zero read permissions.
**Fix:** Added `RUN chmod 644` to the Dockerfile, giving nginx read access while keeping write access restricted to the owner — following least privilege principles.

**Issue 3 — Blank page after permission fix**
The site loaded but rendered blank.
**Root cause:** The `index.html` file had been wiped when manually exec-ing into the container to change permissions. Changes made inside a running container are not persisted in the image.
**Fix:** Rebuilt the image cleanly from scratch with the `chmod` baked into the Dockerfile via `RUN`, avoiding the need to manually exec into the container at all.

---

## What I learned

- How Docker images and containers differ — the image is immutable, the container is the running instance
- Why changes made inside a running container don't persist and how to bake configuration into the image correctly via the Dockerfile
- How Linux file permissions (`chmod 644`) affect what processes can read files — directly relevant to the principle of least privilege from my Security+ studies
- The full ECR workflow: build → tag → authenticate → push
- How to debug containerised apps using `docker exec` and `docker logs`

---

## Background

This project was built as part of my transition from FTTP installation engineering into DevSecOps and cloud engineering. I hold CompTIA A+ and Security+ certifications and am currently working toward AWS Cloud Practitioner.

The goal was to take a real static site, containerise it properly, debug the issues that came up, and push it to a cloud registry — mirroring a real-world deployment workflow.

---

## What's next

- [ ] Set up a GitHub Actions pipeline to build and push to ECR automatically on every commit
- [ ] Deploy the container to AWS ECS so it runs in the cloud, not just locally
- [ ] Add HTTPS via an nginx config update
- [ ] Explore image vulnerability scanning with Trivy before the push step

---

## Author

**DeCrypToji** — transitioning from network infrastructure into DevSecOps
- GitHub: [@DeCrypToji](https://github.com/DeCrypToji)

---

*Fan tribute — Jujutsu Kaisen © Gege Akutami / Shueisha*
