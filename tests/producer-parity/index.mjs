import assert from 'node:assert/strict';
import { readdir, readFile, stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const [metadataPath, packageTreePath, sourcePackageJsonPath, modulePath] = process.argv.slice(2);
assert(metadataPath && packageTreePath && sourcePackageJsonPath && modulePath, 'missing parity inputs');

const metadata = JSON.parse(await readFile(metadataPath, 'utf8'));
const sourcePackageJsonBytes = await readFile(sourcePackageJsonPath, 'utf8');
const emittedPackageJsonBytes = await readFile(path.join(packageTreePath, 'package.json'), 'utf8');
const packageJson = JSON.parse(sourcePackageJsonBytes);
const moduleText = await readFile(modulePath, 'utf8');

assert.equal(metadata.package, '@tummycrypt/tinyland-a11y-engine');
assert.equal(metadata.version, '0.2.5');
assert(metadata.package_target.endsWith('//:pkg'));
assert.equal(metadata.package_owner, metadata.package_target);
assert.equal(metadata.package_tree_is_directory, true);
assert.deepEqual(metadata.package_default_files, [metadata.package_tree]);
assert(metadata.compiled_owner.endsWith('//:tinyland_a11y_engine'));
assert.deepEqual(
  metadata.dependencies.map(({ package: name, version }) => [name, version]),
  [['@tummycrypt/tinyland-color-utils', '0.2.3']],
);
assert(metadata.dependencies[0].store_tree, 'color-utils dependency must use a store tree artifact');
assert(metadata.dependencies[0].files.length > 0, 'color-utils dependency must expose store files');

assert.equal(packageJson.name, metadata.package);
assert.equal(packageJson.version, metadata.version);
assert.equal(emittedPackageJsonBytes, sourcePackageJsonBytes, 'emitted package.json must match source bytes');
assert.match(
  moduleText,
  /module\(\s*name\s*=\s*"tummycrypt_tinyland_a11y_engine",\s*version\s*=\s*"0\.2\.5"/s,
  'MODULE.bazel must declare tummycrypt_tinyland_a11y_engine@0.2.5',
);

async function listFiles(root, directory = root) {
  const entries = await readdir(directory);
  const files = [];
  for (const entry of entries) {
    const absolute = path.join(directory, entry);
    const entryStat = await stat(absolute);
    if (entryStat.isDirectory()) {
      files.push(...await listFiles(root, absolute));
    } else {
      assert(entryStat.isFile(), `package tree contains a non-file entry: ${absolute}`);
      files.push(path.relative(root, absolute).split(path.sep).join('/'));
    }
  }
  return files.sort();
}

const actualFiles = await listFiles(packageTreePath);
const expectedFiles = [
  'LICENSE',
  'README.md',
  'package.json',
  ...metadata.compiled_files,
].sort();
assert.deepEqual(actualFiles, expectedFiles, 'package tree files must exactly match declared producer artifacts');

for (const exportConditions of Object.values(packageJson.exports)) {
  for (const relativeTarget of Object.values(exportConditions)) {
    const target = path.join(packageTreePath, relativeTarget);
    assert((await stat(target)).isFile(), `missing exported package file: ${relativeTarget}`);
  }
}

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

console.log('producer parity: @tummycrypt/tinyland-a11y-engine@0.2.5');
console.log('packaged dependency resolved: @tummycrypt/tinyland-color-utils@0.2.3');
