#!/usr/bin/env bash
set -euo pipefail

readonly expected_version="0.2.5"
ref="${1:?release ref is required}"
if [[ "$ref" != "v${expected_version}" ]]; then
  echo "release ref ${ref} does not match v${expected_version}" >&2
  exit 1
fi

printf 'release_ref=%s\n' "$ref"
