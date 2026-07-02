<script lang="ts">
  import type { Epistemic } from './types';

  let { e }: { e: Epistemic } = $props();

  const titles: Record<Epistemic, string> = {
    obs: 'Observed — directly sourced (liner notes, primary source)',
    inf: 'Inferred — from session lists or cross-references',
    unk: 'Uncertain — genuinely unresolved, not incorrect',
  };
</script>

{#if e === 'inf'}
  <span class="ep-badge inf" title={titles.inf}>inf</span>
{:else if e === 'unk'}
  <span class="ep-badge unk" title={titles.unk}>?</span>
{/if}
<!-- obs renders nothing: the quiet default (style-guide §2) -->
