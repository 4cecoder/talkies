import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

const output = resolve(process.argv[2] ?? 'out');
const pages = [
  ['/', 'index.html'],
  ['/contact/', 'contact/index.html'],
  ['/download/', 'download/index.html'],
  ['/legal/privacy/', 'legal/privacy/index.html'],
  ['/legal/terms/', 'legal/terms/index.html'],
];

assert.ok(existsSync(output), `Static export directory does not exist: ${output}`);
assert.ok(existsSync(join(output, '.nojekyll')), 'GitHub Pages export must include .nojekyll');

for (const [route, file] of pages) {
  const htmlPath = join(output, file);
  assert.ok(existsSync(htmlPath), `Missing static route ${route}: ${file}`);
  const html = readFileSync(htmlPath, 'utf8');
  assert.match(html, /<title>Talkies/i, `Missing Talkies page title at ${route}`);
  assert.doesNotMatch(html, /\/talkies\/talkies\//, `Duplicated Pages base path at ${route}`);

  const localAssets = [...html.matchAll(/(?:src|href)="(\/talkies\/_next\/[^\"]+)"/g)];
  assert.ok(localAssets.length > 0, `No base-path-prefixed Next assets found at ${route}`);
  for (const [, assetUrl] of localAssets) {
    const assetPath = join(output, assetUrl.replace(/^\/talkies\//, ''));
    assert.ok(existsSync(assetPath), `Broken static asset reference at ${route}: ${assetUrl}`);
  }
}

const homepage = readFileSync(join(output, 'index.html'), 'utf8');
assert.match(homepage, /property=\"og:image\" content=\"https:\/\/4cecoder\.github\.io\/talkies\/og-image\.svg\"/, 'Open Graph image must use the Pages site URL');
assert.ok(existsSync(join(output, 'og-image.svg')), 'Open Graph image is missing from the static export');
assert.ok(existsSync(join(output, 'favicon.svg')), 'Favicon is missing from the static export');

console.log(`Verified ${pages.length} GitHub Pages routes and their local static assets in ${output}`);
