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

# System deps: CA certs (for HTTPS upstreams / lists), tzdata (log timestamps)
RUN apk add --no-cache ca-certificates tzdata && \
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

# Default runtime configuration
ENV PORT=8080
ENV TZ=UTC


# Built-in health check: queries "healthcheck.blocky" via loopback DNS.
# Returns exit 0 on NOERROR, exit 1 on anything else.
HEALTHCHECK --start-period=30s --timeout=5s --interval=30s --retries=3 \
  CMD ["/app/blocky", "healthcheck"]

ENTRYPOINT ["/docker-entrypoint.sh"]
