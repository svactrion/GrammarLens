#!/usr/bin/env bash
set -euo pipefail

# Runs the app against a locally-running proxy (see proxy/README.md),
# using config/dev.json for the proxy URL/app token (see README's "Local
# setup" section). The Anthropic API key itself never comes back into the
# client — it's a Worker secret, set once via `wrangler secret put` (or
# `.dev.vars` locally, see proxy/README.md).
#
# Starts `wrangler dev` for the proxy in the background if nothing is
# already answering on its port (so running this twice, or alongside a
# `npm run dev` you started yourself in proxy/, doesn't spawn a second
# one), and stops the one it started on exit. If dev.json's
# PROXY_BASE_URL is ever pointed at something other than localhost (e.g.
# the live proxy, for a one-off test against it — see README), this
# skips starting a local proxy instead of spawning one nothing will use.
# cd's to the repo root first so this works regardless of the caller's
# current directory.
cd "$(dirname "${BASH_SOURCE[0]}")/.."

proxy_base_url=$(grep -o '"PROXY_BASE_URL"[[:space:]]*:[[:space:]]*"[^"]*"' config/dev.json \
  | sed -E 's/.*: *"([^"]*)"/\1/')
proxy_pid=""

if [[ "$proxy_base_url" == http://localhost:* || "$proxy_base_url" == http://127.0.0.1:* ]]; then
  proxy_port="${proxy_base_url##*:}"

  proxy_is_up() {
    curl --silent --output /dev/null --fail "http://localhost:$proxy_port/health"
  }

  if ! proxy_is_up; then
    echo "config/dev.json points at localhost — starting the proxy locally (wrangler dev)..."
    (cd proxy && npm run dev -- --port "$proxy_port") &
    proxy_pid=$!

    for _ in $(seq 1 30); do
      if proxy_is_up; then
        break
      fi
      sleep 1
    done
    if ! proxy_is_up; then
      echo "Proxy did not become ready on port $proxy_port — check proxy/.dev.vars exists" \
        "(copy proxy/.dev.vars.example) and try running 'npm run dev' in proxy/ directly to see the error."
      exit 1
    fi
  fi
else
  echo "config/dev.json points at $proxy_base_url — not starting a local proxy."
fi

cleanup() {
  if [[ -n "$proxy_pid" ]]; then
    kill "$proxy_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT

flutter run --dart-define-from-file=config/dev.json "$@"
