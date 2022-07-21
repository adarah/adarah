<script lang="ts">
	import Chip8 from '$lib/chip-8'
	let gameName: string
</script>

<h1>Welcome to SvelteKit</h1>
<p>Visit <a href="https://kit.svelte.dev">kit.svelte.dev</a> to read the documentation</p>
<select bind:value={gameName}>
	<option value="INVADERS">Space invaders</option>
	<option value="TETRIS">Tetris</option>
</select>

<Chip8 {gameName} />
