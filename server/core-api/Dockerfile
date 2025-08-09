# Build core-api
FROM golang:1.22-alpine AS build
WORKDIR /src
COPY go.mod .
COPY cmd ./cmd
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    cd cmd/coreapi && go build -o /out/coreapi

FROM alpine:3.20
RUN adduser -D app
USER app
WORKDIR /app
COPY --from=build /out/coreapi /app/coreapi
EXPOSE 8080
ENTRYPOINT ["/app/coreapi"]
