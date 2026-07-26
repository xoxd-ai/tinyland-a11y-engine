# @tummycrypt/tinyland-a11y-engine

Accessibility evaluation engine and validators for Tinyland applications.

This package provides reusable contrast, ARIA, keyboard navigation, reporting, streaming, and orchestration utilities intended to be consumed as a standalone building block.

## Build

```bash
nix develop --command just setup
nix develop --command just typecheck
nix develop --command just test
nix develop --command just build
nix develop --command just package
```

`just` is the repository entrypoint. Its build, typecheck, test, and package
recipes use the Nix-provided Bazelisk and the checked-in Bzlmod graph; pnpm is
resolved at the version declared in `MODULE.bazel`, not installed on the host.

## Consumer Proof

```bash
nix develop --command just consumer-smoke
```

This creates an isolated temporary HTTP Bzlmod registry and source archive,
records the archive SRI, and runs downstream `compile_smoke` and
`runtime_smoke` targets against `0.2.5`. It does not mutate the shared registry.

Release review and append-only registry instructions are in
[`docs/release-0.2.5.md`](docs/release-0.2.5.md).
