<script context="module" lang="ts">
	async function getGame(title: string): Promise<Uint8Array> {
		const response = await fetch(`/games/${title}`);
		const buf = await response.arrayBuffer();
		return new Uint8Array(buf);
	}
</script>

<script lang="ts">
	import { browser } from '$app/env';
	import Chip8 from '$lib/chip-8';

	let gameTitle: string = 'INVADERS';
	let gameData: Promise<Uint8Array>;
	$: {
		if (browser) {
			gameData = getGame(gameTitle);
		}
	}
</script>

<select bind:value={gameTitle}>
	<option value="INVADERS">Space invaders</option>
	<option value="TETRIS">Tetris</option>
	<option value="BRIX">Brix</option>
	<option value="PONG2">Pong 2</option>
</select>

{#if browser}
	<Chip8 {gameData} clockFrequencyHz={1000} />
{/if}