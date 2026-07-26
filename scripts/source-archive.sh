#!/usr/bin/env bash
set -euo pipefail

readonly package_name="tinyland-a11y-engine"
readonly package_version="0.2.5"
readonly strip_prefix="${package_name}-${package_version}"

root="$(git rev-parse --show-toplevel)"
output="${1:-${root}/dist/release/${strip_prefix}.tar.gz}"
if [[ "$output" != /* ]]; then
  output="${root}/${output}"
fi

tmp="$(mktemp -d "${TMPDIR:-/tmp}/tinyland-a11y-source-archive.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

manifest="${tmp}/files.list"
cd "$root"
git ls-files --cached --others --exclude-standard -z | LC_ALL=C sort -z >"$manifest"
if [[ ! -s "$manifest" ]]; then
  echo "source archive manifest is empty" >&2
  exit 1
fi

mkdir -p "$(dirname "$output")"
tar \
  --create \
  --file="${tmp}/source.tar" \
  --null \
  --files-from="$manifest" \
  --transform="s#^#${strip_prefix}/#" \
  --mtime='@0' \
  --owner=0 \
  --group=0 \
  --numeric-owner \
  --sort=name
gzip -n -9 -c "${tmp}/source.tar" >"$output"

integrity="$({ python3 - "$output" <<'PY'
import base64
import hashlib
import pathlib
import sys

archive = pathlib.Path(sys.argv[1])
print("sha256-" + base64.b64encode(hashlib.sha256(archive.read_bytes()).digest()).decode("ascii"))
PY
} )"

printf 'archive=%s\n' "$output"
printf 'integrity=%s\n' "$integrity"
printf 'strip_prefix=%s\n' "$strip_prefix"
