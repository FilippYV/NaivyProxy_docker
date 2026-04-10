# ── Этап 1: сборка кастомного Caddy ───────────────────────────────────────────
FROM golang:1.22-bookworm AS builder

WORKDIR /build

# Подменяем TMPDIR — на VPS /tmp часто слишком мал
ENV TMPDIR=/build/tmp
ENV GOPATH=/go
RUN mkdir -p /build/tmp

# Устанавливаем xcaddy и собираем Caddy с плагином NaiveProxy
RUN go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest && \
    /go/bin/xcaddy build \
        --with github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@naive \
        --output /build/caddy

# ── Этап 2: минимальный рантайм-образ ─────────────────────────────────────────
FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/caddy /usr/bin/caddy
RUN chmod +x /usr/bin/caddy

# Caddy будет хранить TLS-сертификаты и состояние в этих томах
RUN mkdir -p /etc/caddy /data/caddy /config/caddy

COPY Caddyfile /etc/caddy/Caddyfile

# Только HTTPS — Caddy сам терминирует TLS (нужно для NaiveProxy)
EXPOSE 443

# Включаем BBR внутри контейнера при запуске, затем стартуем Caddy
CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]