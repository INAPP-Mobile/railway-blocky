# ── Download stage ─────────────────────────────────────────────────────────
#   Fetch the pre-built static binary for the target platform. Building from
#   Go source would add 2-3 minutes and a full Go toolchain every deploy;
#   the official release tarball is ~10 MB and takes seconds.
FROM alpine:3.19 AS download

RUN apk add --no-cache curl tar && \
    curl -fsSL \
      "https://github.com/0xERR0R/blocky/releases/download/v0.32.1/blocky_v0.32.1_Linux_x86_64.tar.gz" \
    | tar xz -C /tmp/

# ── Runtime stage ──────────────────────────────────────────────────────────
FROM alpine:3.19

# Metadata
LABEL org.opencontainers.image.source="https://github.com/INAPP-Mobile/railway-blocky"
LABEL org.opencontainers.image.description="Blocky — DNS-level ad-blocker and privacy tool. Railway template."
LABEL org.opencontainers.image.licenses="Apache-2.0"

# System deps: CA certs (for HTTPS upstreams / lists), tzdata (log timestamps),
# curl (for Docker HEALTHCHECK on the HTTP endpoint)
RUN apk add --no-cache ca-certificates tzdata curl && \
    adduser -D -u 1001 blocky

# Binary
COPY --from=download /tmp/blocky /app/blocky

# Default config and entrypoint wrapper
COPY config.yml       /app/config.yml
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh && \
    chown -R 1001:1001 /app /docker-entrypoint.sh

# Non-root user (matching upstream convention)
USER 1001
WORKDIR /app

# ── Runtime defaults ───────────────────────────────────────────────────────
ENV BLOCKY_CONFIG_FILE=/app/config.yml

# Ports:
#   5353   DNS (TCP+UDP)  — >= 1024 so no CAP_NET_BIND_SERVICE needed.
#                          Use port 53 locally with --cap-add NET_BIND_SERVICE.
#   4000   HTTP  — REST API, Prometheus metrics, DoH
#   Railway health-checks whichever port is set in PORT (default 4000).
EXPOSE 5353 5353/udp 4000

# Default runtime configuration — PORT will be overridden by Railway
ENV PORT=4000
ENV TZ=UTC


# Health check via HTTP endpoint (used by Docker; Railway does its own health
# checks on the PORT variable).  Falls back to exit 0 if curl isn't available.
HEALTHCHECK --start-period=30s --timeout=5s --interval=30s --retries=3 \
  CMD curl -sf "http://127.0.0.1:${PORT:-4000}/" > /dev/null 2>&1 || exit 1

ENTRYPOINT ["/docker-entrypoint.sh"]
