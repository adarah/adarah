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
		getSoundTimer(): number;
		setCurrentTime(now: DOMHighResTimeStamp): void;
	}

	function getRandomSeed() {
		return Math.floor(Math.random() * 2147483647);
	}

	function getGameUrl(title: string): string{
		return new URL(`/games/${title}`, import.meta.url).href;
	}
</script>

<script lang="ts">
	import { onMount } from 'svelte';
	import { genEnv } from './bindings';
	import Canvas from './canvas.svelte';
	import { Chip8Memory } from './chip-8-memory';

	export let gameData: Uint8Array | Promise<Uint8Array>;
	export let seed: number = getRandomSeed();
	export let clockFrequencyHz: number = 500;
	export let quirks: Chip8Quirks = {
		shift: true,
		register: true,
		wrap: true
	};

	let exports: Chip8Exports;
	let animationFrame: number;
	let timerInterval: ReturnType<typeof setInterval>;
	let paused: boolean = true;
	let PC: number;
	let SP: number;
	let registers: Uint8Array;
	let stack: Uint16Array;

	let audio: HTMLAudioElement;

	onMount(() => {
		enableTimers();
		audio = new Audio('/beep3.ogg');
	});
	async function setupMem(gameData: Uint8Array | Promise<Uint8Array>): Promise<Chip8Memory> {
		// These are the number of pages allocated to the binary. Each page has 64KiB
		let memory = new WebAssembly.Memory({ initial: 2, maximum: 2 });
		const imports = {
			env: genEnv(memory)
		};
		// TODO: Fetch binary and game in parallel
		const [source, gameBuf] = await Promise.all([
			await WebAssembly.instantiateStreaming(fetch('/chip-8.wasm'), imports),
			gameData
		]);

		const wholeMem = new Uint8Array(memory.buffer, 0, gameBuf.byteLength);
		wholeMem.set(gameBuf);

		exports = source.instance.exports as unknown as Chip8Exports;
		exports.init(
			seed,
			performance.now(),
			clockFrequencyHz,
			quirks.shift,
			quirks.register,
			wholeMem.byteOffset,
			wholeMem.byteLength
		);
		const memPtr: number = exports.getMemPtr();
		return new Chip8Memory(memory.buffer, memPtr);
	}

	function enableTimers() {
		timerInterval = setInterval(() => {
			exports?.timerTick();
			if (exports?.getSoundTimer() > 0) {
				audio?.play();
			}
		}, 16.667);

		return () => clearInterval(timerInterval);
	}

	function play(mem: Chip8Memory): void {
		exports?.setCurrentTime(performance.now());
		function loop(time: DOMHighResTimeStamp): void {
			exports?.onAnimationFrame(time);
			animationFrame = requestAnimationFrame(loop);
			PC = mem.PC;
			SP = mem.SP;
			registers = mem.registers;
			stack = mem.stack;
		}
		enableTimers();
		animationFrame = requestAnimationFrame(loop);
		paused = false;
	}

	function pause(): void {
		cancelAnimationFrame(animationFrame);
		clearInterval(timerInterval);
		paused = true;
	}

	function toggle(mem: Chip8Memory): void {
		if (paused) {
			play(mem);
		} else {
			pause();
		}
	}

	function keydownHandler(e: KeyboardEvent): void {
		const codepoint = e.key.codePointAt(0);
		if (codepoint === undefined) {
			return;
		}
		exports?.onKeydown(codepoint);
	}

	function keyupHandler(e: KeyboardEvent): void {
		const codepoint = e.key.codePointAt(0);
		if (codepoint === undefined) {
			return;
		}
		exports?.onKeyup(codepoint);
	}
</script>

{#await setupMem(gameData)}
	<p>Loading...</p>
{:then mem}
	<Canvas
		pixelSize={20}
		buffer={mem.display}
		on:keydown={keydownHandler}
		on:keyup={keyupHandler}
		on:focus={() => play(mem)}
		on:blur={pause}
	/>
	<button on:click={() => toggle(mem)}><h1>{paused ? 'Play' : 'Pause'}</h1></button>

	<div>
		<p>seed: {seed}</p>
		<p>PC: {PC?.toString(16)}</p>
		<p>Registers: {registers}</p>
		<p>SP: {SP?.toString(16)}</p>
		<p>Stack: {stack}</p>
		<p>clock speed: {clockFrequencyHz}</p>
		<p>quirks: {JSON.stringify(quirks)}</p>
	</div>
{:catch err}
	<p>Some error: {err}</p>
{/await}
