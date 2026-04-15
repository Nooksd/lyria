FROM golang:1.24-alpine AS builder

RUN apk add --no-cache git

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o lyria_server .

FROM alpine:3.19

RUN apk add --no-cache ffmpeg python3 py3-pip ca-certificates tzdata \
    && pip3 install --break-system-packages "yt-dlp[default]"

WORKDIR /app

COPY --from=builder /app/lyria_server .
COPY --from=builder /app/.env.example .env.example

RUN mkdir -p uploads/image/avatar uploads/image/cover uploads/image/playlist uploads/music uploads/lyrics

EXPOSE 9000

ENV ENVIRONMENT=production

CMD ["./lyria_server"]
