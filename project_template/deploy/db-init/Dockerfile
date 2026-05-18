FROM alpine:3.23

WORKDIR /app

RUN apk add --no-cache ca-certificates postgresql-client

COPY deploy/artifacts/backend/migration /usr/local/bin/migration
COPY deploy/artifacts/backend/xtask /usr/local/bin/xtask
COPY deploy/backend/services.docker.toml /app/config/services.toml
COPY deploy/db-init/entrypoint.sh /usr/local/bin/db-init-entrypoint.sh

RUN chmod +x /usr/local/bin/migration \
    /usr/local/bin/xtask \
    /usr/local/bin/db-init-entrypoint.sh

ENTRYPOINT ["db-init-entrypoint.sh"]
