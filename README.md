# Talkies Website

This branch contains Talkies' static website source. The `master` branch contains the desktop and Android application source; the website has its own branch so its Next.js and Bun dependencies stay out of the application checkout.

## Develop

Requirements: Bun and Node.js.

```sh
bun install --frozen-lockfile
bun run dev
```

## Verify and publish

Pull requests to this branch run lint, static export, and Pages asset checks. Pushes to `website` repeat those checks and publish the static export to the `gh-pages` branch. GitHub Pages serves that branch from its root at <https://4cecoder.github.io/talkies/>.

The exported site is static. Features that require server APIs or a backend are not available in the published Pages build.
