# Release 0.2.5

Version `0.2.5` repairs release metadata and proof infrastructure without
changing the package API. The producer gate binds all of these surfaces:

- `package.json` name and version
- `MODULE.bazel` module name and version
- `//:pkg` `NpmPackageInfo` name, version, owner, tree artifact, and files
- the exact packaged dependency record for
  `@tummycrypt/tinyland-color-utils@0.2.3`
- a runtime import through the linked `//:pkg` artifact

## Review Gate

Run the full non-mutating gate from the locked development shell:

```bash
nix develop --command just release-check
```

The producer commands use the repository's configured local Bazel disk cache.
The consumer proof uses a fresh output user root and repository cache, disables
the disk and remote caches, and forces local spawn strategy. Neither command is
remote-execution evidence.

The runtime checks resolve `tinyland-color-utils@0.2.3` from the packaged a11y
module graph and execute its `ColorCache` implementation. They do not claim
that the immutable color-utils `0.2.3` root entry point is directly loadable by
raw Node 22: that artifact contains extensionless internal ESM imports. Any
broader raw-Node compatibility claim requires a separate color-utils release;
do not rewrite its existing `0.2.3` registry entry or archive.

## Source Archive And SRI

After the release commit is reviewed and before any registry change, generate
the deterministic source archive from that exact clean checkout:

```bash
nix develop --command just source-archive
```

The command prints the archive path, `sha256-...` SRI, and
`tinyland-a11y-engine-0.2.5` strip prefix. The operator must attach those exact
bytes as an immutable `v0.2.5` release asset. Recompute the digest after upload
and require it to match before registration.

The later registry `source.json` must use the printed SRI:

```json
{
  "url": "https://github.com/tinyland-inc/tinyland-a11y-engine/releases/download/v0.2.5/tinyland-a11y-engine-0.2.5.tar.gz",
  "integrity": "sha256-<exact just source-archive output>",
  "strip_prefix": "tinyland-a11y-engine-0.2.5"
}
```

## Append-Only Registry Registration

Registry mutation is a later operator action in `tinyland-inc/bazel-registry`.
It must be an append-only review:

1. Add `modules/tummycrypt_tinyland_a11y_engine/0.2.5/MODULE.bazel` from the
   reviewed release commit.
2. Add `modules/tummycrypt_tinyland_a11y_engine/0.2.5/source.json` with the
   immutable release-asset URL and verified SRI above.
3. Append `"0.2.5"` to the existing `versions` array in
   `modules/tummycrypt_tinyland_a11y_engine/metadata.json`.
4. Do not edit, replace, yank, or regenerate any `0.2.4` path or archive.
5. After registration, rerun equivalent downstream `compile_smoke` and
   `runtime_smoke` targets using only the shared registry entry.

## Release Order

The remaining operator sequence is review and merge, create signed `v0.2.5`,
attach and verify the deterministic archive, submit the append-only registry
review, prove a shared-registry consumer, then publish package artifacts. The
publish workflow validates the same Nix/Just/Bazel gate and checks the release
tag before any package mutation. npmjs publication remains disabled; the
workflow only targets the existing GitHub Packages channel.
