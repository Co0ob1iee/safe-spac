# Build wg-provisioner
FROM golang:1.22-alpine AS build
WORKDIR /src
COPY go.mod .
# Pre-fetch modules and generate go.sum to avoid build failures on missing sums
RUN go mod download
COPY cmd ./cmd
RUN apk add --no-cache git \
    && cd cmd/provisioner \
    && go mod tidy
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    cd cmd/provisioner && go build -o /out/wg-provisioner

FROM alpine:3.20
RUN adduser -D app
USER app
WORKDIR /app
COPY --from=build /out/wg-provisioner /app/wg-provisioner
EXPOSE 8081
ENTRYPOINT ["/app/wg-provisioner"]
