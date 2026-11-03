FROM golang:1.26.10-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags "-s -w" -o /out/ ./cmd/api ./cmd/worker ./cmd/migrate ./cmd/bot

FROM alpine:3.22
RUN adduser -D -u 10001 app
WORKDIR /app
COPY --from=build /out/ ./
COPY config/ ./config/
USER app
ENTRYPOINT []
