FROM nginx:1.25.4-alpine3.18
RUN apk update && apk upgrade openssl
COPY index.html /usr/share/nginx/html/index.html
RUN chmod 644 /usr/share/nginx/html/index.html
EXPOSE 80
# updated
# trivy scan added
