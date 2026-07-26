#!/usr/bin/env bash
set -euo pipefail

readonly expected_version="0.2.5"
readonly github_package_name="@tinyland-inc/tinyland-a11y-engine"
readonly github_registry="https://npm.pkg.github.com"

package_dir="${1:?Bazel package directory is required}"
dry_run="${2:-true}"
if [[ "$dry_run" != "true" && "$dry_run" != "false" ]]; then
  echo "dry_run must be true or false" >&2
  exit 1
fi
if [[ ! -f "${package_dir}/package.json" ]]; then
  echo "package.json not found under ${package_dir}" >&2
  exit 1
fi

tmp="$(mktemp -d "${TMPDIR:-/tmp}/tinyland-a11y-github-package.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
cp -R "$package_dir" "${tmp}/package"
chmod -R u+w "${tmp}/package"

PACKAGE_JSON="${tmp}/package/package.json" \
EXPECTED_VERSION="$expected_version" \
GITHUB_PACKAGE_NAME="$github_package_name" \
GITHUB_REGISTRY="$github_registry" \
node <<'NODE'
const fs = require('node:fs');
const packageJsonPath = process.env.PACKAGE_JSON;
const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
if (packageJson.version !== process.env.EXPECTED_VERSION) {
  throw new Error(`package version ${packageJson.version} does not match ${process.env.EXPECTED_VERSION}`);
}
packageJson.name = process.env.GITHUB_PACKAGE_NAME;
packageJson.publishConfig = {
  ...(packageJson.publishConfig || {}),
  access: 'public',
  registry: process.env.GITHUB_REGISTRY,
};
fs.writeFileSync(packageJsonPath, JSON.stringify(packageJson, null, 2) + '\n');
NODE

publish_args=("${tmp}/package" --access public --ignore-scripts --registry "$github_registry")
if [[ "$dry_run" == "true" ]]; then
  publish_args+=(--dry-run)
else
  readonly expected_confirmation="${github_package_name}@${expected_version}"
  if [[ "${PUBLISH_CONFIRM:-}" != "$expected_confirmation" ]]; then
    echo "PUBLISH_CONFIRM must equal ${expected_confirmation}" >&2
    exit 1
  fi
  : "${NODE_AUTH_TOKEN:?NODE_AUTH_TOKEN is required for publication}"
  if existing_version="$(npm view "${github_package_name}@${expected_version}" version --registry "$github_registry" 2>/dev/null)" && \
    [[ "$existing_version" == "$expected_version" ]]; then
    printf '%s already exists in %s; publication is idempotently complete\n' \
      "${github_package_name}@${expected_version}" \
      "$github_registry"
    exit 0
  fi
fi

npm publish "${publish_args[@]}"
