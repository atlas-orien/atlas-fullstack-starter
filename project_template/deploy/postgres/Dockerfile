FROM postgres:latest

COPY backend/target/release/migration /usr/local/bin/migration
COPY backend/target/release/xtask /usr/local/bin/xtask
COPY deploy/backend/services.docker.toml /app/config/services.toml
COPY deploy/postgres/init-database.sh /docker-entrypoint-initdb.d/10-init-database.sh

RUN chmod +x /usr/local/bin/migration \
    /usr/local/bin/xtask \
    /docker-entrypoint-initdb.d/10-init-database.sh
