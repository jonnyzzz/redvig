#!/bin/sh
# The only supported way to build or preview the redvig website.
# Hugo runs inside a pinned Docker image; the layouts refuse to render otherwise.
#
#   ./website/build.sh              production build into website/public/
#   ./website/build.sh dev [PORT]   live-reload preview at http://localhost:PORT/ (default 1313)
set -eu

site_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
output_dir="$site_dir/public"
image='ghcr.io/gohugoio/hugo:v0.169.0@sha256:a146e0639230bbc73358e6563240f0a6103466f0390b80a457c775068ec802a9'

usage() {
  sed -n '2,7s/^# \{0,1\}//p' "$0" >&2
  exit 2
}

if ! command -v docker >/dev/null 2>&1; then
  echo 'build.sh: docker is required to build the website' >&2
  exit 1
fi

# Shared container settings. HUGO_REDVIG_DOCKER is checked by layouts/home.html,
# so running Hugo outside this script fails instead of producing a site.
run_hugo() {
  docker run --rm --init \
    --user "$(id -u):$(id -g)" \
    --env HUGO_CACHEDIR=/tmp/hugo-cache \
    --env HUGO_REDVIG_DOCKER=1 \
    --mount "type=bind,source=$site_dir,target=/project,readonly" \
    --entrypoint /usr/bin/hugo \
    "$@"
}

build() {
  mkdir -p "$output_dir"
  run_hugo --network none \
    --mount "type=bind,source=$output_dir,target=/output" \
    "$image" --source /project --destination /output --environment production \
    --noBuildLock --minify --cleanDestinationDir --panicOnWarning

  test -s "$output_dir/index.html"
  test "$(cat "$output_dir/CNAME")" = redvig.dev
  for asset in logo-light.svg mark.svg favicon.ico apple-touch-icon.png preview.png; do
    test -s "$output_dir/assets/$asset"
  done
  printf 'Website built in %s\n' "$output_dir"
}

dev() {
  port=${1:-1313}
  case $port in
    '' | *[!0-9]*) echo "build.sh: invalid port: $port" >&2; exit 2 ;;
  esac
  tty_flags=''
  if [ -t 0 ] && [ -t 1 ]; then tty_flags='--interactive --tty'; fi
  printf 'Serving http://localhost:%s/ (Ctrl+C to stop)\n' "$port"
  # shellcheck disable=SC2086
  run_hugo $tty_flags \
    --publish "127.0.0.1:$port:1313" \
    "$image" server --source /project --environment development \
    --bind 0.0.0.0 --port 1313 --baseURL "http://localhost:$port/" \
    --appendPort=false --liveReloadPort "$port" \
    --renderToMemory --noBuildLock --buildDrafts --disableFastRender --poll 500ms --panicOnWarning
}

case ${1:-build} in
  build) [ $# -le 1 ] || usage; build ;;
  dev) shift; [ $# -le 1 ] || usage; dev "$@" ;;
  -h | --help | help) usage ;;
  *) usage ;;
esac
