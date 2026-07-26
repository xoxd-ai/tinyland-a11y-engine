#!/usr/bin/env bash
set -euo pipefail

readonly module_name="tummycrypt_tinyland_a11y_engine"
readonly module_version="0.2.5"
readonly color_module_version="0.2.3"
readonly tinyland_registry="https://raw.githubusercontent.com/tinyland-inc/bazel-registry/main"
readonly central_registry="https://bcr.bazel.build"

root="$(git rev-parse --show-toplevel)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/tin-2906-registry-smoke.XXXXXX")"
server_pid=""
cleanup() {
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  rm -rf "$tmp"
}
trap cleanup EXIT

serve_root="${tmp}/http"
registry_root="${serve_root}/registry"
archive_dir="${serve_root}/archives"
module_dir="${registry_root}/modules/${module_name}/${module_version}"
consumer_root="${tmp}/consumer"
mkdir -p "$archive_dir" "$module_dir" "$consumer_root"

archive="${archive_dir}/tinyland-a11y-engine-${module_version}.tar.gz"
archive_metadata="$(cd "$root" && bash scripts/source-archive.sh "$archive")"
integrity="$(printf '%s\n' "$archive_metadata" | sed -n 's/^integrity=//p')"
strip_prefix="$(printf '%s\n' "$archive_metadata" | sed -n 's/^strip_prefix=//p')"
if [[ -z "$integrity" || -z "$strip_prefix" ]]; then
  echo "source archive did not report integrity and strip_prefix" >&2
  exit 1
fi

printf '{"mirrors":[]}\n' >"${registry_root}/bazel_registry.json"
mkdir -p "${registry_root}/modules/${module_name}"
jq -n \
  --arg version "$module_version" \
  '{homepage:"https://github.com/tinyland-inc/tinyland-a11y-engine",maintainers:[],versions:[$version],yanked_versions:{}}' \
  >"${registry_root}/modules/${module_name}/metadata.json"
cp "${root}/MODULE.bazel" "${module_dir}/MODULE.bazel"

port_fifo="${tmp}/registry-port.fifo"
mkfifo "$port_fifo"
python3 -c '
import functools
import http.server
import sys

root = sys.argv[1]
handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=root)
server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
print(server.server_address[1], flush=True)
server.serve_forever()
' "$serve_root" >"$port_fifo" 2>"${tmp}/http.log" &
server_pid="$!"
IFS= read -r port <"$port_fifo"
rm -f "$port_fifo"
if [[ -z "$port" ]]; then
  echo "temporary registry server did not report a port" >&2
  exit 1
fi

registry_url="http://127.0.0.1:${port}/registry"
archive_url="http://127.0.0.1:${port}/archives/$(basename "$archive")"
jq -n \
  --arg integrity "$integrity" \
  --arg strip_prefix "$strip_prefix" \
  --arg url "$archive_url" \
  '{url:$url,integrity:$integrity,strip_prefix:$strip_prefix}' \
  >"${module_dir}/source.json"

cat >"${consumer_root}/MODULE.bazel" <<EOF
module(name = "tin_2906_consumer", version = "0.0.0")

bazel_dep(name = "aspect_rules_js", version = "2.9.1")
bazel_dep(name = "aspect_rules_ts", version = "3.8.4")
bazel_dep(name = "rules_nodejs", version = "6.7.3")
bazel_dep(name = "${module_name}", version = "${module_version}")

node = use_extension("@rules_nodejs//nodejs:extensions.bzl", "node")
node.toolchain(node_version = "22.13.1")

rules_ts_ext = use_extension("@aspect_rules_ts//ts:extensions.bzl", "ext")
rules_ts_ext.deps(ts_version = "5.9.3")
use_repo(rules_ts_ext, "npm_typescript")
EOF

cat >"${consumer_root}/BUILD.bazel" <<'EOF'
load("@aspect_rules_js//js:defs.bzl", "js_test")
load("@aspect_rules_js//npm:defs.bzl", "npm_link_package")
load("@aspect_rules_ts//ts:defs.bzl", "ts_project")

npm_link_package(
    name = "node_modules/@tummycrypt/tinyland-a11y-engine",
    src = "@tummycrypt_tinyland_a11y_engine//:pkg",
)

ts_project(
    name = "compile_smoke",
    srcs = ["compile_smoke.ts"],
    declaration = False,
    no_emit = True,
    transpiler = "tsc",
    tsconfig = "tsconfig.json",
    deps = [":node_modules/@tummycrypt/tinyland-a11y-engine"],
)

js_test(
    name = "runtime_smoke",
    data = [":node_modules/@tummycrypt/tinyland-a11y-engine"],
    entry_point = "runtime_smoke.mjs",
    node_options = ["--experimental-import-meta-resolve"],
)
EOF

cat >"${consumer_root}/compile_smoke.ts" <<'EOF'
import { parseColor, rgbToOklch, type RGB } from '@tummycrypt/tinyland-a11y-engine/color';

const parsed: RGB | null = parseColor('#336699');
if (!parsed || rgbToOklch(parsed).l <= 0) {
  throw new Error('compile smoke failed');
}
EOF

cat >"${consumer_root}/runtime_smoke.mjs" <<'EOF'
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const a11yRuntimeUrl = import.meta.resolve('@tummycrypt/tinyland-a11y-engine/browser-runtime');
const { createBrowserA11yRuntime } = await import(a11yRuntimeUrl);
const runtime = createBrowserA11yRuntime({
  evaluate() {},
  flush() {},
  initialize() {},
  isCircuitBreakerOpen() { return false; },
  recoverConnection() {},
  testConnection() { return true; },
});
assert.equal(typeof runtime.startHeadlessTelemetry, 'function');

const colorEntry = fileURLToPath(
  import.meta.resolve('@tummycrypt/tinyland-color-utils', a11yRuntimeUrl),
);
const colorPackageJsonPath = path.resolve(path.dirname(colorEntry), '..', 'package.json');
const colorPackageJson = JSON.parse(await readFile(colorPackageJsonPath, 'utf8'));
assert.equal(colorPackageJson.name, '@tummycrypt/tinyland-color-utils');
assert.equal(colorPackageJson.version, '0.2.3');

const colorCacheUrl = pathToFileURL(
  path.resolve(path.dirname(colorEntry), 'utils', 'color', 'cache.js'),
);
const { ColorCache } = await import(colorCacheUrl);
const cache = new ColorCache(2);
cache.set('resolved-through-a11y', true);
assert.equal(cache.get('resolved-through-a11y'), true);
console.log('runtime_smoke resolved tinyland-color-utils through the packaged a11y graph');
EOF

cat >"${consumer_root}/tsconfig.json" <<'EOF'
{
  "compilerOptions": {
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "strict": true,
    "target": "ES2022"
  }
}
EOF
printf '%s\n' '8.1.1' >"${consumer_root}/.bazelversion"

bazel_startup=(
  --output_user_root="${tmp}/bazel-output-user-root"
  --ignore_all_rc_files
)
bazel_common=(
  --enable_bzlmod
  --registry="$registry_url"
  --registry="$tinyland_registry"
  --registry="$central_registry"
  --repository_cache="${tmp}/repository-cache"
  --disk_cache=
  --remote_cache=
  --remote_executor=
  --spawn_strategy=local
  --verbose_failures
)

printf 'temporary_registry=%s\n' "$registry_url"
printf 'archive_integrity=%s\n' "$integrity"
printf 'archive_strip_prefix=%s\n' "$strip_prefix"
printf 'transitive_dependency=%s@%s\n' 'tummycrypt_tinyland_color_utils' "$color_module_version"

cd "$consumer_root"
bazelisk "${bazel_startup[@]}" build "${bazel_common[@]}" //:compile_smoke
bazelisk "${bazel_startup[@]}" test "${bazel_common[@]}" --test_output=errors //:runtime_smoke

printf '%s\n' 'consumer proof execution=local repository_cache=isolated disk_cache=disabled remote_cache=disabled remote_execution=disabled'
