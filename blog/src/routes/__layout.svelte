<script lang="ts">
  import CaretLeft from '$lib/icons/caret-left.svelte';
  import CaretRight from '$lib/icons/caret-right.svelte';
  import Sidebar from '$lib/sidebar.svelte';
  import '../styles/globals.css';
  import '../styles/reset.css';

  let sidebarOpen: boolean = true;

  function handleClick(): void {
    sidebarOpen = !sidebarOpen;
  }
</script>

<div id="root" data-testid="root">
  <Sidebar open={sidebarOpen} />
  <div class="button">
    {#if sidebarOpen}
      <CaretLeft on:click={handleClick} />
    {:else}
      <CaretRight on:click={handleClick} />
    {/if}
  </div>
  <main>
    <slot />
  </main>
</div>

<style>
  #root {
    display: flex;
    height: 100%;
    --sidebar-width: 250px;
    --padding-top: 50px;
    --padding-bottom: 30px;
    --button-size: 30px;
  }
  main {
    padding-top: var(--padding-top);
    padding-bottom: var(--padding-bottom);
    padding-right: var(--button-size);
    width: 90%;
    max-width: 700px;
    margin: 0 auto;
  }

  .button {
    flex-shrink: 0;
    flex-grow: 0;
    transform: translateX(-8px);
    align-self: center;
    background-color: aliceblue;
    border: solid 1px gray;
    border-radius: 100%;
    width: var(--button-size);
    transition: background-color 0.3s;
  }
  .button :global(svg) {
    vertical-align: center;
    width: var(--button-size);
    height: var(--button-size);
  }

  .button:hover {
    background-color: gray;
  }
</style>
