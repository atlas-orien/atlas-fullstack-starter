FROM rust:alpine

ENV PATH="/usr/local/cargo/bin:${PATH}"

RUN apk add --no-cache \
    build-base \
    ca-certificates \
    curl \
    musl-dev \
    openssl-dev \
    openssl-libs-static \
    pkgconfig \
    zlib-dev \
    zlib-static

ENV OPENSSL_STATIC=1

WORKDIR /workspace/backend
