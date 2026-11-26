#!/bin/sh
# Live-reload preview of the redvig website with the pinned Hugo binary.
# Production builds go through Bazel: ./bazelw build //website:site
#
#   ./bazelw run //website:dev            preview at http://localhost:1313/
#   ./bazelw run //website:dev -- PORT    preview on another port
set -eu

usage() {
  sed -n '2,7s/^# \{0,1\}//p' "$0" >&2
  exit 2
}

if [ -z "${BUILD_WORKSPACE_DIRECTORY:-}" ] || [ $# -lt 1 ]; then
  echo 'dev.sh: run it with ./bazelw run //website:dev' >&2
  exit 2
fi
# The first argument is the Hugo binary, passed by the //website:dev target.
hugo=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
shift

[ $# -le 1 ] || usage
case ${1:-} in -h | --help | help) usage ;; esac
port=${1:-1313}
case $port in
  '' | *[!0-9]*) echo "dev.sh: invalid port: $port" >&2; exit 2 ;;
esac

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/redvig/hugo"
printf 'Serving http://localhost:%s/ (Ctrl+C to stop)\n' "$port"
# Serve the real sources, not runfiles, so edits reload.
# HUGO_REDVIG_BAZEL is checked by layouts/baseof.html, so Hugo run any other way fails.
cd "$BUILD_WORKSPACE_DIRECTORY/website"
HUGO_CACHEDIR=$cache_dir HUGO_REDVIG_BAZEL=1 exec "$hugo" server \
  --source . --environment development \
  --bind 127.0.0.1 --port "$port" --baseURL "http://localhost:$port/" \
  --renderToMemory --noBuildLock --buildDrafts --disableFastRender --panicOnWarning
