
FROM nginx:alpine

ARG RELEASE_MODE=NORMAL

COPY index.html /usr/share/nginx/html/index.html
COPY health.html /tmp/health.html

RUN if [ "$RELEASE_MODE" = "NORMAL" ]; then \
      cp /tmp/health.html /usr/share/nginx/html/health.html; \
    fi

EXPOSE 80
