<script context="module" lang="ts">
	function* pixelPos(): Generator<[number, number]> {
		for (let y = 0; y < 32; y++) {
			for (let x = 0; x < 64; x++) {
				yield [x, y];
			}
		}
	}
	function* bitsOf(num: number): Generator<0 | 1> {
		for (let i = 7; i >= 0; i--) {
			const masked = num & (1 << i);
			yield masked ? 1 : 0;
		}
	}
</script>

<script lang="ts">
	import { onMount } from 'svelte';
	import { blur } from 'svelte/transition';

	export let paused: boolean;
	export let pixelSize: number;
	export let buffer: Uint8Array;
	console.log(buffer);

	let canvas: HTMLCanvasElement;
	let ctx: CanvasRenderingContext2D;

	onMount(() => {
		console.log('mounted canvas!');
		canvas.width = pixelSize * 64;
		canvas.height = pixelSize * 32;
		ctx = canvas.getContext('2d')!;

		let frame: number;
		function loop() {
			render(buffer);
			frame = requestAnimationFrame(loop);
		}

		loop();
		return () => cancelAnimationFrame(frame);
	});

	function render(buffer: Uint8Array): void {
		const pos = pixelPos();
		for (let _byte of buffer.values()) {
			for (let bit of bitsOf(_byte)) {
				const [x, y] = pos.next().value;

				ctx.fillStyle = bit === 1 ? 'white' : 'black';
				const pixelX = pixelSize * x;
				const pixelY = pixelSize * y;
				ctx.fillRect(pixelX, pixelY, pixelX + pixelSize, pixelY + pixelSize);
			}
		}
	}
</script>

<div class="container">
	<canvas
		tabindex="0"
		class="item"
		bind:this={canvas}
		on:keydown
		on:keyup
		on:focus
		on:blur
	/>
	{#if paused}
		<div class="item" class:paused transition:blur={{ duration: 300 }}>
			<div class="pause-icon" />
			<div class="pause-icon" />
		</div>
	{/if}
</div>

<style>
	.item {
		width: 50%;
	}
	.container {
		position: relative;
	}

	.paused {
		position: absolute;
		pointer-events: none;
		inset: 0px;
		background-color: black;
		opacity: 0.8;
		display: flex;
		column-gap: 5%;
		justify-content: center;
		align-items: center;
	}

	.pause-icon {
		background-color: white;
		pointer-events: none;
		height: 30%;
		width: 5%;
	}
</style>
