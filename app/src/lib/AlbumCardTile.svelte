<script lang="ts">
  import type { AlbumCard } from './types';

  let { album, onopen }: { album: AlbumCard; onopen: (id: string) => void } = $props();

  let artFailed = $state(false);
</script>

<button class="card" onclick={() => onopen(album.id)} title={`${album.title} — ${album.artist} (${album.year})`}>
  <div class="art">
    {#if !artFailed}
      <img
        src={album.artUrl}
        alt={`${album.title} cover`}
        loading="lazy"
        onerror={() => (artFailed = true)}
      />
    {:else}
      <div class="art-fallback">
        <span class="display fallback-title">{album.title}</span>
      </div>
    {/if}
    <span class="year-badge">{album.year}</span>
  </div>
  <div class="meta">
    <span class="title">{album.title}</span>
    <span class="artist">{album.artist}</span>
    <span class="style display">{album.style}</span>
  </div>
</button>

<style>
  .card {
    position: absolute;
    width: 148px;
    padding: 0;
    border: 1px solid var(--line);
    border-radius: 6px;
    background: var(--surface);
    text-align: left;
    overflow: hidden;
    transition: box-shadow 120ms ease, transform 120ms ease, border-color 120ms ease;
  }
  .card:hover, .card:focus-visible {
    border-color: var(--bn-blue-light);
    box-shadow: 0 4px 14px rgba(28, 26, 23, 0.14);
    transform: translateY(-2px);
    outline: none;
  }
  .art {
    position: relative;
    width: 146px;
    height: 146px;
    background: var(--line);
  }
  .art img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
  }
  .art-fallback {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 10px;
    background: linear-gradient(160deg, rgba(43, 95, 122, 0.16), rgba(43, 95, 122, 0.05));
    border-bottom: 1px solid var(--line);
  }
  .fallback-title {
    font-size: 15px;
    color: var(--bn-blue);
    text-align: center;
    line-height: 1.2;
  }
  .year-badge {
    position: absolute;
    left: 6px;
    bottom: 6px;
    font-family: var(--font-display);
    font-weight: 600;
    font-size: 12.5px;
    letter-spacing: 0.04em;
    color: var(--bg);
    background: rgba(28, 26, 23, 0.82);
    padding: 2px 7px;
    border-radius: 4px;
  }
  .meta {
    display: flex;
    flex-direction: column;
    gap: 1px;
    padding: 7px 9px 8px;
  }
  .title {
    font-size: 12.5px;
    font-weight: 600;
    color: var(--ink);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .artist {
    font-size: 11.5px;
    color: var(--muted);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .style {
    font-size: 11px;
    color: var(--bn-blue);
    font-variant: small-caps;
    letter-spacing: 0.04em;
  }
</style>
