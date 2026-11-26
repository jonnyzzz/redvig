#!/bin/sh
# Bazel action: build a Hugo site with the pinned Hugo binary.
#
#   hugo_build.sh HUGO OUT_DIR SITE_ROOT FILE...
#
# The sandbox presents inputs as symlinks, which Hugo does not follow, so the sources are
# copied (symlinks resolved) into a private directory first.
set -eu

hugo=$1 out_dir=$2 site_root=$3
shift 3

work=$(mktemp -d "${TMPDIR:-/tmp}/hugo-build.XXXXXX")
trap 'rm -rf "$work"' EXIT
mkdir "$work/src"

for file in "$@"; do
  rel=${file#"$site_root"/}
  [ "$rel" != "$file" ] || { echo "hugo_build.sh: $file is outside $site_root" >&2; exit 1; }
  mkdir -p "$work/src/$(dirname "$rel")"
  cp -L "$file" "$work/src/$rel"
done

mkdir -p "$out_dir"
out_dir=$(cd "$out_dir" && pwd)

# HUGO_REDVIG_BAZEL is checked by layouts/baseof.html, so Hugo run any other way fails.
# HOME and the cache point into the private directory, so no user config is read.
env -i \
  PATH=/usr/bin:/bin \
  HOME="$work/home" \
  HUGO_CACHEDIR="$work/cache" \
  HUGO_REDVIG_BAZEL=1 \
  "$hugo" --source "$work/src" --destination "$out_dir" --environment production \
  --noBuildLock --minify --panicOnWarning --quiet
