<script lang="ts" context="module">
	export interface Chip8Quirks {
		shift: boolean;
		register: boolean;
		wrap: boolean;
	}

	interface Chip8Exports {
		init(
			seed: number,
			startTime: number,
			clockFrequencyHz: number,
			shiftQuirk: boolean,
			registerQuirk: boolean,
			gameData: number,
			gameLength: number
		): void;
		getMemPtr(): number;
		onKeydown(keycode: number): void;
		onKeyup(keycode: number): void;
		onAnimationFrame(time: DOMHighResTimeStamp): void;
		timerTick(): void;
	}

	function getRandomSeed() {
		return Math.floor(Math.random() * 2147483647);
	}
</script>

<script lang="ts">
	import { onMount } from 'svelte';
	import { genEnv } from './bindings';
	import Canvas from './canvas.svelte';
	import { Chip8Memory } from './chip-8-memory';

	export let gameName: string;
	export let seed: number = getRandomSeed();
	export let clockFrequencyHz: number = 500;
	export let quirks: Chip8Quirks = {
		shift: true,
		register: true,
		wrap: true
	};

	let onAnimationFrame: (time: DOMHighResTimeStamp) => void;
	let timerTick: () => void;
	let onKeydown: (keycode: number) => void;
	let onKeyup: (keycode: number) => void;
	let animationFrame: number;
	let paused: boolean = true;

	onMount(() => {
		const timerInterval = setInterval(() => {
			timerTick?.();
		}, 16.667);

		return () => clearInterval(timerInterval);
	});
	async function setupMem(gameName: string): Promise<Chip8Memory> {
		// These are the number of pages allocated to the binary. Each page has 64KiB
		let memory = new WebAssembly.Memory({ initial: 2, maximum: 2 });
		const imports = {
			env: genEnv(memory)
		};
		// TODO: Fetch binary and game in parallel
		const [source, gameRes] = await Promise.all([
			await WebAssembly.instantiateStreaming(fetch('/chip-8.wasm'), imports),
			await fetch(`/games/${gameName}`).then((d) => d.arrayBuffer())
		]);
		const gameBuf = new Uint8Array(gameRes);

		const wholeMem = new Uint8Array(memory.buffer, 0, gameBuf.byteLength);
		wholeMem.set(gameBuf);

		const exports = source.instance.exports as unknown as Chip8Exports;
		exports.init(
			seed,
			performance.now(),
			clockFrequencyHz,
			quirks.shift,
			quirks.register,
			wholeMem.byteOffset,
			wholeMem.byteLength
		);
		onAnimationFrame = exports.onAnimationFrame;
		onKeydown = exports.onKeydown;
		onKeyup = exports.onKeyup;
		timerTick = exports.timerTick;

		const memPtr: number = exports.getMemPtr();
		return new Chip8Memory(memory.buffer, memPtr);
	}

	function play(): void {
		function loop(time: DOMHighResTimeStamp): void {
			onAnimationFrame(time);
			animationFrame = requestAnimationFrame(loop);
		}
		animationFrame = requestAnimationFrame(loop);
		paused = false;
	}

	function pause(): void {
		cancelAnimationFrame(animationFrame);
		paused = true;
	}

	function toggle(): void {
		if (paused) {
			play();
		} else {
			pause();
		}
	}

	function keydownHandler(e: KeyboardEvent): void {
		const codepoint = e.key.codePointAt(0);
		if (codepoint === undefined) {
			return;
		}
		onKeydown?.(codepoint);
	}

	function keyupHandler(e: KeyboardEvent): void {
		const codepoint = e.key.codePointAt(0);
		if (codepoint === undefined) {
			return;
		}
		onKeyup?.(codepoint);
	}
</script>

{#await setupMem(gameName)}
	<p>Loading...</p>
{:then mem}
	<Canvas
		pixelSize={10}
		buffer={mem.display}
		on:keydown={keydownHandler}
		on:keyup={keyupHandler}
		on:focus={play}
		on:blur={pause}
	/>
	<button on:click={toggle}>{paused ? 'Play' : 'Pause'}</button>
{:catch err}
	<p>Some error: {err}</p>
{/await}

<div>
	<p>{seed}</p>
	<p>{clockFrequencyHz}</p>
	<p>{JSON.stringify(quirks)}</p>
	<p>{gameName}</p>
</div>
