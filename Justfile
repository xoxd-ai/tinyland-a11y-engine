set shell := ["bash", "-euo", "pipefail", "-c"]

root := justfile_directory()

default:
    @just --list --unsorted

info:
    @cd "{{ root }}" && printf 'node=%s\nnpm=%s\nbazelisk=%s\n' \
        "$(node --version)" \
        "$(npm --version)" \
        "$(bazelisk version 2>/dev/null | head -n1)"

setup:
    cd "{{ root }}" && bazelisk fetch //:pkg //:typecheck //:test //:producer_parity //:package_check

build:
    cd "{{ root }}" && bazelisk build //:tinyland_a11y_engine

typecheck:
    cd "{{ root }}" && bazelisk build //:typecheck

test:
    cd "{{ root }}" && bazelisk test //:test //:producer_parity

package:
    cd "{{ root }}" && bazelisk build //:pkg
    cd "{{ root }}" && bazelisk test //:producer_parity //:package_check
    cd "{{ root }}" && npm pack --dry-run --ignore-scripts ./bazel-bin/pkg

consumer-smoke:
    cd "{{ root }}" && bash scripts/isolated-registry-consumer-smoke.sh

check: typecheck test build package

ci: check consumer-smoke

release-check: ci

source-archive output="dist/release/tinyland-a11y-engine-0.2.5.tar.gz":
    cd "{{ root }}" && bash scripts/source-archive.sh "{{ output }}"

package-artifact output="dist/ci/bazel-pkg.tar.gz":
    cd "{{ root }}" && bash scripts/package-artifact.sh "{{ output }}"

release-ref-check ref:
    cd "{{ root }}" && bash scripts/release-ref-check.sh "{{ ref }}"

github-package-publish package_dir dry_run="true":
    cd "{{ root }}" && bash scripts/publish-github-package.sh "{{ package_dir }}" "{{ dry_run }}"
