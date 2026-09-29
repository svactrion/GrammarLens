#!/usr/bin/env bash
set -euo pipefail

# The Daily Test fallback pool, from sets the live cron published
# (docs/1.1.0-shared-daily-test.md §5; lib/data/fallback_pool.dart).
#
#   scripts/fallback_pool.sh fetch <date>...   read set:<date> from KV (read-only)
#   scripts/fallback_pool.sh build <date>...   check + write the pool asset and review
#   scripts/fallback_pool.sh test              the converter's own tests
#
# fetch only ever runs `wrangler kv key get` (--remote, DAILY_SETS_KV): it
# never writes, lists or deletes anything in KV. Its output goes to
# tool/fallback_pool/raw/ (ignored by git). build reads those files, runs every
# set through the proxy's own gate (validateSharedSet with the date's plan),
# requires prompt v2 and exactly 7 dates, and writes
# assets/daily_test_fallback/pool.json and tool/fallback_pool/review.md only
# if every set passes; then the app-side check (test/fallback_pool_test.dart)
# runs on the written asset. Needs `npm install` in proxy/ (for esbuild), and
# for fetch a `wrangler login`.
cd "$(dirname "${BASH_SOURCE[0]}")/.."

esbuild=proxy/node_modules/.bin/esbuild
out=tool/fallback_pool/.build

bundle() {
  "$esbuild" "tool/fallback_pool/$1.ts" --bundle --platform=node --format=esm \
    --log-level=warning --outfile="$out/$1.mjs"
}

cmd="${1:-}"
shift || true
case "$cmd" in
  fetch)
    [[ $# -gt 0 ]] || { echo "usage: $0 fetch <YYYY-MM-DD>..." >&2; exit 2; }
    mkdir -p tool/fallback_pool/raw
    for date in "$@"; do
      [[ "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { echo "not a date: $date" >&2; exit 2; }
      (cd proxy && npx wrangler kv key get --binding DAILY_SETS_KV --remote "set:$date") \
        > "tool/fallback_pool/raw/set-$date.json"
      echo "fetched set:$date"
    done
    ;;
  build)
    [[ $# -gt 0 ]] || { echo "usage: $0 build <YYYY-MM-DD>..." >&2; exit 2; }
    bundle export
    node "$out/export.mjs" "$@"
    flutter test test/fallback_pool_test.dart
    ;;
  test)
    bundle convert.test
    node --test "$out/convert.test.mjs"
    ;;
  *)
    echo "usage: $0 fetch|build <YYYY-MM-DD>... | test" >&2
    exit 2
    ;;
esac
