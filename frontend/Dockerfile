FROM nginxinc/nginx-unprivileged:stable-alpine
COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template
COPY --chown=101:101 public/ /usr/share/nginx/html/
EXPOSE 8080
