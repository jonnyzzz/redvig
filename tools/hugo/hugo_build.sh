#!/bin/sh
# Bazel action: build a Hugo site in the pinned Docker image.
#
#   hugo_build.sh DOCKER IMAGE_FILE OUT_DIR SITE_ROOT FILE...
#
# The sources are copied (symlinks resolved) into a tar and streamed to the container on
# stdin; the site comes back as a tar on stdout. Nothing is bind-mounted, so this works
# from the Bazel sandbox and with a remote Docker daemon. The container has no network.
set -eu

docker=$1 image_file=$2 out_dir=$3 site_root=$4
shift 4

image=$(cat "$image_file")
work=$(mktemp -d "${TMPDIR:-/tmp}/hugo-build.XXXXXX")
trap 'rm -rf "$work"' EXIT
mkdir "$work/src"

for file in "$@"; do
  rel=${file#"$site_root"/}
  [ "$rel" != "$file" ] || { echo "hugo_build.sh: $file is outside $site_root" >&2; exit 1; }
  mkdir -p "$work/src/$(dirname "$rel")"
  cp -L "$file" "$work/src/$rel"
done
# No extended attributes: macOS tar adds them and the GNU tar in the image warns.
COPYFILE_DISABLE=1 tar --no-xattrs -c -f "$work/src.tar" -C "$work/src" .

# HUGO_REDVIG_DOCKER is checked by layouts/baseof.html, so Hugo run any other way fails.
"$docker" run --rm --interactive --network none \
  --env HUGO_CACHEDIR=/tmp/hugo-cache \
  --env HUGO_REDVIG_DOCKER=1 \
  --entrypoint /bin/sh \
  "$image" -c '
    set -eu
    mkdir /tmp/src /tmp/out
    tar -x -f - -C /tmp/src
    hugo --source /tmp/src --destination /tmp/out --environment production \
      --noBuildLock --minify --panicOnWarning --quiet >&2
    tar -c -f - -C /tmp/out .
  ' <"$work/src.tar" >"$work/out.tar"

mkdir -p "$out_dir"
tar -x -f "$work/out.tar" -C "$out_dir"
