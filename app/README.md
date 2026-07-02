# A Jazz Canon — app

Static single-page app (Svelte 5 + Vite + TypeScript) for *The Jazz Canon*:
a timeline of ~100 canonical jazz albums (1949–1972) with per-track
personnel, Apple Music previews, and a scoped collaboration graph
("Constellation").

See `../docs/DECISIONS.md` for the architecture and every design decision,
and `../docs/DEPLOY.md` for the Cloudflare Pages deploy.

## Develop

```bash
npm install
npm run dev      # local dev server
npm run build    # production build → dist/
npm run preview  # serve the production build
npm run check    # svelte-check + tsc
```

## Data

The app reads three static JSON files in `public/data/` (`albums.json`,
`details.json`, `graph.json`), produced from the Postgres dump by
`../scripts/export.sh`, then enriched with Apple 30-second preview URLs by
`../scripts/enrich-previews.mjs`. Regenerate only when the dataset changes;
the committed JSON is ready to build against as-is.
