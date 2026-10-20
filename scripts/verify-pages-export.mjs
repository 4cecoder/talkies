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
assert.doesNotMatch(homepage, /Live Transcription Demo|Try It Now - Right in Your Browser|Xenova\/whisper-base/i, 'The static homepage must not include the browser ML demo');
assert.match(homepage, /property=\"og:image\" content=\"https:\/\/(?:talkies\.app\/og-image\.svg|4cecoder\.github\.io\/talkies\/og-image\.svg)\"/, 'Open Graph image must use the site URL for the active build target');
assert.ok(existsSync(join(output, 'og-image.svg')), 'Open Graph image is missing from the static export');
assert.ok(existsSync(join(output, 'favicon.svg')), 'Favicon is missing from the static export');

// Landing page structure: landmarks, section anchors used by the header and footer, and the hero canvas.
for (const landmark of [/<header[\s>]/, /<main[^>]*id="main"/, /<footer[\s>]/]) {
  assert.match(homepage, landmark, `Homepage is missing landmark ${landmark}`);
}
for (const id of ['how', 'engines', 'platforms', 'open-source', 'faq']) {
  assert.match(homepage, new RegExp(`id="${id}"`), `Homepage is missing the #${id} section`);
}
assert.equal((homepage.match(/<h1[\s>]/g) ?? []).length, 1, 'Homepage must have exactly one <h1>');
assert.match(homepage, /<canvas[^>]*>/, 'Homepage hero canvas is missing');
assert.match(homepage, /class="hero-fallback/, 'Homepage hero must render the CSS gradient fallback');
assert.match(homepage, /Phonon-2/, 'Homepage must describe the Phonon-2 engine');
assert.match(homepage, /localStorage\.getItem\('talkies-theme'\)/, 'Theme bootstrap script is missing');

// Static, local-first site: no analytics, trackers, or remote fonts.
for (const [route, file] of pages) {
  const html = readFileSync(join(output, file), 'utf8');
  assert.doesNotMatch(
    html,
    /googletagmanager|google-analytics|gtag\(|plausible\.io|segment\.com|fonts\.googleapis|fonts\.gstatic/i,
    `Tracking script or remote font found at ${route}`,
  );
}

console.log(`Verified ${pages.length} GitHub Pages routes and their local static assets in ${output}`);
