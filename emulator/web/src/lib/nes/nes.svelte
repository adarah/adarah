<script lang="ts">
	import { Nes } from './nes';
  async function init() {
    const nes = await Nes.init({ code: fetch('/nes.wasm') })
    nes.main();
    console.log('called main');
  }
</script>

{#await init()}
	<p>Loading...</p>
{:then}
	<p>Finished loading</p>
{:catch}
	<p>Could not load nes</p>
{/await}
