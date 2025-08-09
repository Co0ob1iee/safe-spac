# Build core-api
FROM golang:1.23-alpine AS build
WORKDIR /src
COPY go.mod .
# Pre-fetch modules and generate go.sum to avoid build failures on missing sums
RUN go mod download
COPY cmd ./cmd
# Ensure VCS tools are available for fetching modules and tidy the module
RUN apk add --no-cache git \
    && cd cmd/coreapi \
    && go mod tidy
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    cd cmd/coreapi && go build -o /out/coreapi

FROM alpine:3.20
RUN apk add --no-cache curl \
    && adduser -D app
USER app
WORKDIR /app
COPY --from=build /out/coreapi /app/coreapi
EXPOSE 8080
ENTRYPOINT ["/app/coreapi"]
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -fsS http://localhost:8080/ >/dev/null || exit 1
