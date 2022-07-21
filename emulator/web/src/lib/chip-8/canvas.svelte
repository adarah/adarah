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

	export let pixelSize: number;
	export let buffer: Uint8Array;
    console.log(buffer);

	let canvas: HTMLCanvasElement;
	let ctx: CanvasRenderingContext2D;

	onMount(() => {
        canvas.tabIndex = 1;
		canvas.width = pixelSize * 65;
		canvas.height = pixelSize * 33;
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

<canvas bind:this={canvas} on:keydown on:keyup on:blur />

<style>
    canvas {
        border: solid 15px black;
    }

</style>