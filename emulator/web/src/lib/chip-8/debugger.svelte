<script lang="ts">
	import type { Chip8 } from './chip-8';

	export let enabled: boolean = false;
	export let PC: number = 0x1CF;
	export let SP: number = 0xEFD;
	export let registers: Uint8Array = new Uint8Array();
	export let stack: Uint16Array = new Uint16Array();
	export let chip8: Chip8;
</script>

{#if enabled}
	<div>
		<p>PC: {PC.toString(16)}</p>
		<p>Registers: {registers}</p>
		<p>SP: {SP.toString(16)}</p>
		<p>Stack: {stack}</p>
	</div>
{/if}
<slot />
