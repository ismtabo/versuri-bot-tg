#########################################################
# Develenv stage
#########################################################
FROM golang:1.16.4-alpine3.13 AS develenv
RUN apk add --no-cache git make bash gcc docker-cli curl
WORKDIR /src
ENV CGO_ENABLED=0 GOOS=linux GOARCH=amd64
# Speed up dependencies download
COPY go.mod go.sum ./
RUN go mod download -x

ARG DOCKERIZE_VERSION=v0.6.1
ARG DOCKERIZE_URL="https://github.com/jwilder/dockerize/releases/download/${DOCKERIZE_VERSION}/dockerize-alpine-linux-amd64-${DOCKERIZE_VERSION}.tar.gz"
RUN wget "${DOCKERIZE_URL}" -O /tmp/dockerize-alpine-linux-amd64-${DOCKERIZE_VERSION}.tar.gz \
    && tar -C /usr/local/bin -xzvf /tmp/dockerize-alpine-linux-amd64-${DOCKERIZE_VERSION}.tar.gz \
    && rm /tmp/dockerize-alpine-linux-amd64-${DOCKERIZE_VERSION}.tar.gz

#########################################################
# Build stage
#########################################################
FROM develenv AS build
# Copy project
COPY . /src
# Version
ARG PRODUCT_VERSION
ARG PRODUCT_REVISION
# Build the application
RUN make build-bin build-config

#########################################################
# Production stage
#########################################################
FROM gcr.io/distroless/base
USER nobody
COPY --from=build --chown=nobody:nobody /src/build/bin /app
WORKDIR /app
ENTRYPOINT ["./server"]
