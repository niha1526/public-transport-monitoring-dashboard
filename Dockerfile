FROM nginx:alpine

# NORMAL  -> ships health.html (pods become Ready)
# FAULTY  -> omits health.html (readiness probe fails, triggers rollback test)
ARG RELEASE_MODE=NORMAL

COPY index.html /usr/share/nginx/html/index.html
COPY health.html /tmp/health.html

RUN if [ "$RELEASE_MODE" = "NORMAL" ]; then \
      cp /tmp/health.html /usr/share/nginx/html/health.html; \
    fi && \
    rm -f /tmp/health.html

EXPOSE 80
