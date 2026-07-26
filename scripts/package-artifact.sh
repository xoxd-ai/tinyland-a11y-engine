#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
output="${1:-${root}/dist/ci/bazel-pkg.tar.gz}"
if [[ "$output" != /* ]]; then
  output="${root}/${output}"
fi
if [[ ! -f "${root}/bazel-bin/pkg/package.json" ]]; then
  echo "bazel-bin/pkg is missing; run just package first" >&2
  exit 1
fi

mkdir -p "$(dirname "$output")"
tar --create --gzip --file="$output" --directory="${root}/bazel-bin" pkg
printf 'package_artifact=%s\n' "$output"
