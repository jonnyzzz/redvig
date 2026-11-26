#!/bin/sh
set -eu

site_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
output_dir="$site_dir/public"
image='ghcr.io/gohugoio/hugo:v0.169.0@sha256:a146e0639230bbc73358e6563240f0a6103466f0390b80a457c775068ec802a9'

mkdir -p "$output_dir"
docker run --rm --network none \
  --user "$(id -u):$(id -g)" \
  --env HUGO_CACHEDIR=/tmp/hugo-cache \
  --mount "type=bind,source=$site_dir,target=/project,readonly" \
  --mount "type=bind,source=$output_dir,target=/output" \
  --entrypoint /usr/bin/hugo \
  "$image" --source /project --destination /output --environment production \
  --noBuildLock --minify --cleanDestinationDir --panicOnWarning

test -s "$output_dir/index.html"
test "$(cat "$output_dir/CNAME")" = redvig.dev
for asset in logo-light.svg mark.svg favicon.ico apple-touch-icon.png preview.png; do
  test -s "$output_dir/assets/$asset"
done
printf 'Website built in %s\n' "$output_dir"
