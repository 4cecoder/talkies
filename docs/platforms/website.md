# Website

The public Talkies website is maintained on its own [`website` source branch](https://github.com/4cecoder/talkies/tree/website), separate from the application source on `master`. The `website` branch is a standalone Next.js project with its own lockfile, build checks, and Pages deploy workflow. The [`gh-pages` branch](https://github.com/4cecoder/talkies/tree/gh-pages) contains only the generated static site published by GitHub Pages.

## Develop

Clone the website branch and run it with Bun:

```sh
git clone --branch website --single-branch https://github.com/4cecoder/talkies.git talkies-website
cd talkies-website
bun install --frozen-lockfile
bun run dev
```

For a production preview, set `GITHUB_PAGES=true`, `NEXT_PUBLIC_BASE_PATH=/talkies`, and `NEXT_PUBLIC_SITE_URL=https://4cecoder.github.io/talkies`, then run `bun run build`. The exported site is written to `out/`.

## Checks and deployment

Pull requests to `website` run lint, build the static export, and verify expected routes and local assets. Pushes to `website` run the same checks, then publish `out/` to the `gh-pages` branch. The repository's Pages setting serves that branch from its root at <https://4cecoder.github.io/talkies/>. The deployment uses GitHub Pages only; Vercel is not used.

The public website is static. It has no production server, account backend, billing, or server-side API routes. Browser transcription runs locally in the browser.
