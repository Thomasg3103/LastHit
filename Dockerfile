# Only used by the old lasthit.onrender.com service: it redirects to the static site.
FROM nginx:1.27-alpine
ENV PORT=80
COPY redirect.conf.template /etc/nginx/templates/default.conf.template
