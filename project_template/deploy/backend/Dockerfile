FROM alpine:3.23

WORKDIR /app

RUN apk add --no-cache ca-certificates

COPY deploy/artifacts/backend/web-server /usr/local/bin/web-server
COPY deploy/backend/services.docker.toml /app/config/services.toml

EXPOSE 19878

CMD ["web-server"]
