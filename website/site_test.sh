#!/bin/sh
# Checks the built site: the pages, the Pages custom domain, and the shared assets.
set -eu

site=$1
fail() { echo "FAIL: $*" >&2; exit 1; }

for page in index.html pricing/index.html; do
  test -s "$site/$page" || fail "missing page $page"
done
test "$(cat "$site/CNAME")" = redvig.dev || fail 'CNAME is not redvig.dev'
for asset in logo-light.svg mark.svg favicon.ico apple-touch-icon.png preview.png identity.css site.css; do
  test -s "$site/assets/$asset" || fail "missing asset $asset"
done
grep -q 'https://redvig.dev/' "$site/index.html" || fail 'index.html does not use the production baseURL'
echo "OK: $site"
