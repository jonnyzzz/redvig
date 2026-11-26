#!/bin/sh
# Live-reload preview of the redvig website in the pinned Hugo image.
# Production builds go through Bazel: ./bazelw build //website:site
#
#   ./bazelw run //website:dev            preview at http://localhost:1313/
#   ./bazelw run //website:dev -- PORT    preview on another port
set -eu

# Under `bazel run` this script runs from runfiles; serve the real sources so edits reload.
if [ -n "${BUILD_WORKSPACE_DIRECTORY:-}" ]; then
  repo_dir=$BUILD_WORKSPACE_DIRECTORY
else
  repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
fi
site_dir="$repo_dir/website"
image=$(cat "$repo_dir/tools/hugo/IMAGE")

usage() {
  sed -n '2,7s/^# \{0,1\}//p' "$0" >&2
  exit 2
}

[ $# -le 1 ] || usage
case ${1:-} in -h | --help | help) usage ;; esac
port=${1:-1313}
case $port in
  '' | *[!0-9]*) echo "dev.sh: invalid port: $port" >&2; exit 2 ;;
esac

if ! command -v docker >/dev/null 2>&1; then
  echo 'dev.sh: docker is required to preview the website' >&2
  exit 1
fi

tty_flags=''
if [ -t 0 ] && [ -t 1 ]; then tty_flags='--interactive --tty'; fi
printf 'Serving http://localhost:%s/ (Ctrl+C to stop)\n' "$port"
# HUGO_REDVIG_DOCKER is checked by layouts/baseof.html, so Hugo run any other way fails.
# shellcheck disable=SC2086
exec docker run --rm --init $tty_flags \
  --user "$(id -u):$(id -g)" \
  --env HUGO_CACHEDIR=/tmp/hugo-cache \
  --env HUGO_REDVIG_DOCKER=1 \
  --mount "type=bind,source=$site_dir,target=/project,readonly" \
  --publish "127.0.0.1:$port:1313" \
  --entrypoint /usr/bin/hugo \
  "$image" server --source /project --environment development \
  --bind 0.0.0.0 --port 1313 --baseURL "http://localhost:$port/" \
  --appendPort=false --liveReloadPort "$port" \
  --renderToMemory --noBuildLock --buildDrafts --disableFastRender --poll 500ms --panicOnWarning
