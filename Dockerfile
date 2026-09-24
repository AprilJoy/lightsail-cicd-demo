FROM nginx:stable-alpine

ARG VERSION=local

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /tmp/index.html

RUN sed "s/__VERSION__/${VERSION}/g" /tmp/index.html > /usr/share/nginx/html/index.html \
    && printf 'ok' > /usr/share/nginx/html/health \
    && rm /tmp/index.html

EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/health | grep -qx ok
