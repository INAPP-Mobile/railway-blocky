#!/bin/sh
# Blocky Railway Template — Entrypoint
#
#  1. If BLOCKY_CONFIG is set (base64-encoded YAML), decode it and write
#     to BLOCKY_CONFIG_FILE.  This lets you paste an entire Blocky config
#     as a single Railway secret.
#  2. Otherwise uses the shipped /app/config.yml (defaults below).
#  3. Adjust http port in config to match Railway's PORT env var
#     (Railway injects PORT for health checks and routing).
#  4. Exec into blocky.
#
set -e

if [ -n "${BLOCKY_CONFIG}" ]; then
  echo "==> Decoding BLOCKY_CONFIG..."
  printf "%s" "${BLOCKY_CONFIG}" | base64 -d > "${BLOCKY_CONFIG_FILE}"
elif [ ! -f "${BLOCKY_CONFIG_FILE}" ]; then
  echo "==> WARNING: No config file found at ${BLOCKY_CONFIG_FILE}"
  echo "    Blocky will fail to start. Set BLOCKY_CONFIG or mount a config."
fi

# ── Railway PORT compatibility ─────────────────────────────────────────────
# Railway injects PORT for health checks and HTTP routing.  Override the
# http port in the blocky config to match so Railway can reach the health
# endpoint.
if [ -n "${PORT}" ] && [ "${PORT}" != "4000" ]; then
  echo "==> Adjusting http port from 4000 to ${PORT} for Railway compatibility"
  sed -i "s/^  http:.*/  http: ${PORT}/" "${BLOCKY_CONFIG_FILE}"
fi

echo "==> Starting Blocky v$(/app/blocky version 2>/dev/null || echo '?')"
exec /app/blocky --config "${BLOCKY_CONFIG_FILE}"
