// Enrich details.json with Apple 30-second preview URLs (and Apple track
// ids) by looking each album up in the public iTunes API and matching its
// songs to our tracks. Run AFTER export.sh (which regenerates details.json).
//
//   node scripts/enrich-previews.mjs
//
// Resilient by design: any album that fails to look up or match is simply
// left without previews and reported; the build never depends on it.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const dir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', 'app', 'public', 'data');
const albums = JSON.parse(fs.readFileSync(path.join(dir, 'albums.json'), 'utf8'));
const details = JSON.parse(fs.readFileSync(path.join(dir, 'details.json'), 'utf8'));

const norm = (s) =>
  (s || '')
    .toLowerCase()
    .replace(/\(.*?\)|\[.*?\]/g, '')      // drop "(take 2)", "[alternate]"
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

let albumsHit = 0, albumsMissed = 0, tracksMatched = 0, tracksTotal = 0;
const misses = [];

for (const a of albums) {
  const detail = details[a.id];
  if (!detail) continue;
  tracksTotal += detail.tracks.length;
  if (!a.appleAlbumId) { albumsMissed++; misses.push(`${a.id} (no appleAlbumId)`); continue; }

  let songs = [];
  try {
    const res = await fetch(
      `https://itunes.apple.com/lookup?id=${a.appleAlbumId}&entity=song&limit=200`,
      { signal: AbortSignal.timeout(15000) }
    );
    const json = await res.json();
    songs = (json.results || []).filter((r) => r.wrapperType === 'track' && r.kind === 'song');
  } catch (err) {
    albumsMissed++; misses.push(`${a.id} (lookup failed: ${err})`);
    await sleep(250);
    continue;
  }

  if (!songs.length) { albumsMissed++; misses.push(`${a.id} (no songs)`); await sleep(200); continue; }
  albumsHit++;

  // index songs by (disc, trackNumber) and by normalized title
  const byNum = new Map();
  const byTitle = new Map();
  for (const s of songs) {
    byNum.set(`${s.discNumber ?? 1}-${s.trackNumber}`, s);
    byTitle.set(norm(s.trackName), s);
  }

  for (const t of detail.tracks) {
    // primary: track number on disc 1; fallback: normalized title
    let s = byNum.get(`1-${t.n}`) || byTitle.get(norm(t.title));
    if (s && s.previewUrl) {
      t.previewUrl = s.previewUrl;
      t.appleTrackId = String(s.trackId);
      tracksMatched++;
    }
  }

  await sleep(220); // be gentle with the public API
}

fs.writeFileSync(path.join(dir, 'details.json'), JSON.stringify(details));
console.log(
  `enrich-previews: albums ${albumsHit} matched / ${albumsMissed} missed; ` +
  `tracks ${tracksMatched}/${tracksTotal} got previews`
);
if (misses.length) console.log('  no previews for:\n   ' + misses.join('\n   '));
