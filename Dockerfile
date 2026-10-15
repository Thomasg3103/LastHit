FROM nginx:1.27-alpine
# Render sets PORT; fall back to 80 when run locally
ENV PORT=80
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
COPY index.html /usr/share/nginx/html/index.html
