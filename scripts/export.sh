#!/usr/bin/env bash
# Export The Jazz Canon dataset from the restored scratch database into
# static JSON consumed by the app. Runs psql as the postgres superuser
# (peer auth via sudo); output files are written by this shell as $USER.
#
# Produces (in app/public/data/):
#   albums.json  — 100 timeline cards
#   details.json — per-album deep-dive detail, keyed by album id
#   graph.json   — performance edge list + people, for the Personnel Network
set -euo pipefail

DB=jazzcanon_fable
PSQL=(sudo -n -u postgres psql -p 5433 -d "$DB" -v ON_ERROR_STOP=1 -X -q -At)
OUT="$(cd "$(dirname "$0")/.." && pwd)/app/public/data"
mkdir -p "$OUT"

# --- assert expected counts before exporting anything ---
counts=$("${PSQL[@]}" -c "SELECT (SELECT count(*) FROM _jazzcanon.album)||'/'||(SELECT count(*) FROM _jazzcanon.person)||'/'||(SELECT count(*) FROM _jazzcanon.track)||'/'||(SELECT count(*) FROM _jazzcanon.performance)")
if [[ "$counts" != "100/567/666/670" ]]; then
  echo "COUNT MISMATCH: got $counts, expected 100/567/666/670" >&2
  exit 1
fi

# --- albums.json ---
"${PSQL[@]}" <<'SQL' > "$OUT/albums.json"
SELECT json_agg(r ORDER BY r.year, r.id)
FROM (
  SELECT a.id, a.title, a.artist_name AS artist, a.year,
         l.name AS label, a.catalog_number AS catalog,
         s.display_name AS style, s.code AS "styleCode",
         aa.source_url AS "artUrl", a.apple_album_id AS "appleAlbumId"
  FROM _jazzcanon.album a
  LEFT JOIN _jazzcanon.label l ON l.id = a.label_id
  JOIN _jazzcanon.style s ON s.id = a.style_primary_id
  LEFT JOIN _jazzcanon.album_art aa ON aa.album_id = a.id AND aa.is_primary
) r;
SQL

# --- details.json ---
"${PSQL[@]}" <<'SQL' > "$OUT/details.json"
SELECT json_object_agg(a.id, json_build_object(
  'description', a.description,
  'recordingDates', a.recording_dates_text,
  'leader', lead.canonical_name,
  'studios', (
     SELECT coalesce(json_agg(DISTINCT st.name), '[]'::json)
     FROM _jazzcanon.session se
     JOIN _jazzcanon.studio st ON st.id = se.studio_id
     WHERE se.album_id = a.id),
  'tracks', (
     SELECT coalesce(json_agg(json_build_object(
              'n', t.track_number, 'title', t.title, 'side', t.side,
              'duration', t.duration_text, 'appleTrackId', t.apple_track_id,
              'e', t.epistemic_track,
              'personnel', (
                 SELECT coalesce(json_agg(json_build_object(
                          'personId', tp.person_id, 'name', tp.canonical_name,
                          'instrument', tp.instrument, 'e', tp.epistemic)
                        ORDER BY fam.ord, tp.instrument, tp.canonical_name), '[]'::json)
                 FROM _jazzcanon.v_track_personnel tp
                 JOIN _jazzcanon.instrument ins ON ins.name = tp.instrument
                 CROSS JOIN LATERAL (SELECT array_position(
                    ARRAY['brass','woodwinds','keyboards','strings','percussion','other']::text[],
                    ins.family::text) AS ord) fam
                 WHERE tp.track_id = t.id)
            ) ORDER BY t.track_number), '[]'::json)
     FROM _jazzcanon.track t WHERE t.album_id = a.id),
  'personnel', (
     SELECT coalesce(json_agg(json_build_object(
              'personId', row."personId", 'name', row.name,
              'entries', row.entries, 'scope', row.scope)
            ORDER BY row.ord, row.name), '[]'::json)
     FROM (
       SELECT pe.id AS "personId", pe.canonical_name AS name,
              json_agg(json_build_object('instrument', i.name, 'e', p.epistemic)
                       ORDER BY i.name) AS entries,
              min(p.scope::text) AS scope,
              min(array_position(
                 ARRAY['brass','woodwinds','keyboards','strings','percussion','other']::text[],
                 i.family::text)) AS ord
       FROM _jazzcanon.performance p
       JOIN _jazzcanon.person pe ON pe.id = p.person_id
       JOIN _jazzcanon.instrument i ON i.id = p.instrument_id
       WHERE p.album_id = a.id
       GROUP BY pe.id, pe.canonical_name
     ) row)
))
FROM _jazzcanon.album a
LEFT JOIN _jazzcanon.person lead ON lead.id = a.leader_person_id;
SQL

# --- graph.json ---
"${PSQL[@]}" <<'SQL' > "$OUT/graph.json"
SELECT json_build_object(
  'people', (
     SELECT json_object_agg(pe.id, pe.canonical_name)
     FROM _jazzcanon.person pe
     WHERE EXISTS (SELECT 1 FROM _jazzcanon.performance p WHERE p.person_id = pe.id)),
  'edges', (
     SELECT json_agg(e) FROM (
       SELECT p.person_id AS p, p.album_id AS a,
              json_agg(json_build_object('instrument', i.name, 'e', p.epistemic)
                       ORDER BY i.name) AS entries
       FROM _jazzcanon.performance p
       JOIN _jazzcanon.instrument i ON i.id = p.instrument_id
       GROUP BY p.person_id, p.album_id
     ) e)
);
SQL

# --- validate output ---
node - "$OUT" <<'JS'
const fs = require('fs'), path = process.argv[2];
const albums = JSON.parse(fs.readFileSync(path + '/albums.json', 'utf8'));
const details = JSON.parse(fs.readFileSync(path + '/details.json', 'utf8'));
const graph = JSON.parse(fs.readFileSync(path + '/graph.json', 'utf8'));
const assert = (c, m) => { if (!c) { console.error('EXPORT ASSERT FAILED: ' + m); process.exit(1); } };
assert(albums.length === 100, 'albums=' + albums.length);
assert(Object.keys(details).length === 100, 'details=' + Object.keys(details).length);
assert(albums.every(a => a.artUrl), 'every album has artUrl');
assert(albums.filter(a => a.appleAlbumId).length === 98, 'appleAlbumId count');
const nTracks = Object.values(details).reduce((s, d) => s + d.tracks.length, 0);
assert(nTracks === 666, 'tracks=' + nTracks);
const pairs = graph.edges.length;
const perfs = graph.edges.reduce((s, e) => s + e.entries.length, 0);
assert(perfs === 670, 'performance entries=' + perfs);
assert(Object.keys(graph.people).length > 0, 'people present');
const kb = f => Math.round(fs.statSync(path + '/' + f).size / 1024);
console.log(`OK  albums.json ${kb('albums.json')}KB  details.json ${kb('details.json')}KB  graph.json ${kb('graph.json')}KB  (${pairs} person-album edges, ${perfs} performances)`);
JS
