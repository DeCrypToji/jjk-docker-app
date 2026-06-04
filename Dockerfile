FROM nginx:1.27-alpine
RUN apk update && apk upgrade openssl
COPY index.html /usr/share/nginx/html/index.html
RUN chmod 644 /usr/share/nginx/html/index.html
EXPOSE 80
# updated
# trivy scan added
