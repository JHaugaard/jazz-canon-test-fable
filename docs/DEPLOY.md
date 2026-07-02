# Deployment — Cloudflare Pages (prepared, not executed)

The build artifact is a fully static directory: `app/dist/` (HTML + JS + CSS
+ the three data JSON files + brand SVGs). No server, no environment
variables, no build-time secrets. Cover art is hotlinked from Cover Art
Archive / iTunes CDN per DECISIONS.md D6.

## One-time refresh of the artifact

```bash
cd app
./../scripts/export.sh              # only if the database changed
node ../scripts/enrich-previews.mjs # add Apple 30-second preview URLs (needs network)
npm run build                       # emits app/dist
```

`enrich-previews.mjs` must run after `export.sh` (which regenerates
`details.json`). It is resilient: albums it can't look up are simply left
without preview buttons, and the build never depends on it.

## Deploy commands (owner runs these)

First time (creates the Pages project):

```bash
cd app
npx wrangler login                                  # if not already authed
npx wrangler pages project create jazz-canon-fable --production-branch main
```

Every deploy:

```bash
cd app
npx wrangler pages deploy dist --project-name jazz-canon-fable
```

Wrangler prints the `*.pages.dev` URL on success. Custom domain, if wanted
later, is attached in the Cloudflare dashboard under the Pages project.

## Notes

- `app/wrangler.toml` pins the project name and `dist` output dir, so the
  bare `npx wrangler pages deploy` form also works from `app/`.
- No `_redirects` needed: the app is a single page with no client routes.
- Wrangler 4.106.0 is already available on this machine (verified).
