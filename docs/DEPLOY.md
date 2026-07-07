# Deployment — Cloudflare Pages (live)

Production: **https://jazz-canon.pages.dev** — Cloudflare Pages project
**`jazz-canon`** (pinned in `app/wrangler.toml`, first deployed 2026-07-03).

The build artifact is a fully static directory: `app/dist/` (HTML + JS + CSS
+ the data JSON files + brand SVGs). No server, no environment variables, no
build-time secrets. Cover art is hotlinked from Cover Art Archive / iTunes
CDN per DECISIONS.md D6.

## Every deploy (owner runs these)

```bash
cd app
npm run build                 # emits app/dist
npx wrangler pages deploy     # project + output dir come from wrangler.toml
```

Wrangler prints a `*.jazz-canon.pages.dev` preview URL and promotes the
deploy to production on success. That's the whole procedure for code-only
changes — the data JSONs in `app/public/data/` pass through the build
unchanged.

## When the dataset changes

The data exporter lives in the platform project, not this repo (this repo's
`app/public/data/*.json` are gitignored and generated). After a re-export
lands new `albums.json` / `details.json` / `graph.json`:

```bash
node scripts/enrich-previews.mjs   # re-add Apple 30-second preview URLs (needs network)
cd app && npm run build
npx wrangler pages deploy
```

`enrich-previews.mjs` must run after every export — the export regenerates
`details.json` without preview URLs. It is resilient: albums it can't look
up are simply left without preview buttons, and the build never depends on
it. It's also idempotent and safe to re-run any time (e.g. if Apple's CDN
preview links rot months from now).

## Notes

- `app/wrangler.toml` pins the project name (`jazz-canon`) and `dist` output
  dir, so the bare `npx wrangler pages deploy` form works from `app/`.
  Don't pass `--project-name` — a mistyped name silently creates a new,
  empty Pages project.
- Wrangler auth is interactive (`npx wrangler login`, already done on vps8);
  headless/scripted deploys would need a `CLOUDFLARE_API_TOKEN` instead.
- No `_redirects` needed: the app is a single page with no client routes.
- Custom domain, if wanted later, is attached in the Cloudflare dashboard
  under the Pages project.
