# @tummycrypt/tinyland-a11y-engine

Accessibility evaluation engine and validators for Tinyland applications:
WCAG contrast analysis, ARIA validation, keyboard navigation checks,
reporting, streaming and orchestration.

## Consume (Bazel only)

This package is distributed through the Bazel module graph, not npm (RU6).

```starlark
# MODULE.bazel
bazel_dep(name = "tummycrypt_tinyland_a11y_engine", version = "1.0.0")
bazel_dep(name = "tummycrypt_tinyland_color_utils", version = "1.0.0")
```

```starlark
# BUILD.bazel (the package that holds your root node_modules)
npm_link_package(
    name = "node_modules/@tummycrypt/tinyland-color-utils",
    src = "@tummycrypt_tinyland_color_utils//:pkg",
)

npm_link_package(
    name = "node_modules/@tummycrypt/tinyland-a11y-engine",
    src = "@tummycrypt_tinyland_a11y_engine//:pkg",
    deps = {
        ":.aspect_rules_js/node_modules/@tummycrypt/tinyland-color-utils": "@tummycrypt/tinyland-color-utils",
    },
)
```

with `--registry=https://raw.githubusercontent.com/xoxd-ai/bazel-registry/main`
ahead of BCR. The root entry, `./validators` and `./color` import
`@tummycrypt/tinyland-color-utils` at runtime. `//:pkg` deliberately carries no
npm links of its own: a link carried from another Bazel repo is a relative
symlink into `external/<repo>`, which does not exist in a consumer's runfiles
under Bazel 8. Linking color-utils in your own root package and passing it as
`deps` keeps every link inside your repo.

`svelte` (5.57.2) and `axe-core` (4.x) are optional peers that
your own lock provides: the root entry re-exports the Svelte preprocessor and
action, and `./browser` loads `axe-core`.

## Develop

```bash
pnpm install --frozen-lockfile   # lock for npm_translate_lock
bazel build //:pkg               # local, non-qualifying
bazel test //...                 # local, non-qualifying: vitest suite and the tsc 7 typecheck
```

CI (`.github/workflows/ci.yml`, `bazel_targets: "//:pkg //:test"`) builds
`//:pkg` and `//:test`. It does not run the vitest suite or build
`//:typecheck`, so this repo has no qualifying test gate yet. A local run is
a non-qualifying check, and `.bazelrc` sets `startup --max_idle_secs=120`,
so its Bazel server exits after 120 s idle.

`@tummycrypt/tinyland-color-utils` resolves only through Bazel, so the
type check and tests run under Bazel rather than plain `pnpm`.

See [CHANGELOG.md](CHANGELOG.md) for the 1.0.0 migration notes.
