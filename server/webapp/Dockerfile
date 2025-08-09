# Simple static web server for public pages
FROM nginx:alpine
RUN apk add --no-cache curl
COPY --chown=nginx:nginx public/ /usr/share/nginx/html/
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -fsS http://localhost/ >/dev/null || exit 1