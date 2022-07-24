<script lang="ts">
	import { onDestroy, afterUpdate } from 'svelte';
	import Canvas from './canvas.svelte';
	import { Chip8, type Chip8Quirks } from './chip-8';
	import Debugger from './debugger.svelte';
	import { fade } from 'svelte/transition';
	import { easingInterval } from '../../util/easing-interval';

	export let gameData: Promise<Uint8Array>;
	export let seed: number | undefined = undefined;
	export let clockFrequencyHz: number | undefined = undefined;
	export let quirks: Chip8Quirks | undefined = undefined;
	export let audio: HTMLAudioElement = new Audio('/boop4.mp3');

	// Emulation values
	let chip8: Chip8;
	let PC: number;
	let SP: number;
	let registers: Uint8Array;
	let stack: Uint16Array;

	// UI State
	let paused = true;
	let debug = false;
	let focused = false;

	// Timers
	let animationFrame: number;
	let timerInterval: ReturnType<typeof setInterval>;

	$: resetAndLoad(gameData);

	onDestroy(() => {
		clearInterval(timerInterval);
		cancelInterval?.();
		cancelAnimationFrame(animationFrame);
	});

	async function init(): Promise<void> {
		const [_chip8, game] = await Promise.all([
			Chip8.init({
				code: fetch('/chip-8.wasm'),
				audio,
				seed,
				clockFrequencyHz,
				quirks
			}),
			gameData
		]);
		chip8 = _chip8;
		chip8.loadGame(game);
	}

	async function resetAndLoad(gameData: Promise<Uint8Array>) {
		if (!chip8) {
			return;
		}
		chip8.reset();
		const game = await gameData;
		chip8.loadGame(game);
	}

	function play(): void {
		function loop(): void {
			if (!debug) {
				chip8.step();
			}
			animationFrame = requestAnimationFrame(loop);
			PC = chip8.PC;
			SP = chip8.SP;
			registers = chip8.registers;
			stack = chip8.stack;
		}
		chip8.resume();
		animationFrame = requestAnimationFrame(loop);
		timerInterval = setInterval(() => chip8.timerTick(), 16.667);
		paused = false;
	}

	function pause(): void {
		clearInterval(timerInterval);
		paused = true;
	}

	function handleKeydown(e: KeyboardEvent) {
		if (debug) {
			return;
		}
		if (e.key === ' ') {
			paused ? play() : pause();
			return;
		}
		chip8.onKeydown(e.key);
	}

	function handleKeyup(e: KeyboardEvent) {
		if (debug) {
			return;
		}
		chip8.onKeyup(e.key);
	}

	function handleFocus() {
		focused = true;
	}
	function handleBlur() {
		focused = false;
		pause();
	}
	function startDebug() {
		debug = true;
	}
	function endDebug() {
		debug = false;
	}
	function toggleDebug() {
		paused = debug;
		focused = true;
		debug ? endDebug() : startDebug();
	}

	let cancelInterval: (() => void) | undefined;
	function startHold(e: KeyboardEvent | PointerEvent) {
		if (e instanceof KeyboardEvent && e.key !== ' ') {
			return;
		}
		if (cancelInterval) {
			cancelInterval();
		}
		cancelInterval = easingInterval(() => {chip8.debugStep(); console.log('called!')}, 50);
	}

	function endHold() {
		cancelInterval?.();
		cancelInterval = undefined;
	}
</script>

{#await init()}
	<p>Loading...</p>
{:then}
	<div id="work-area">
		<Debugger {chip8} enabled={debug} {PC} {SP} {registers} {stack}>
			<Canvas
				{paused}
				pixelSize={20}
				buffer={chip8.display}
				on:keydown={handleKeydown}
				on:keyup={handleKeyup}
				on:focus={handleFocus}
				on:blur={handleBlur}
			/>
			{#if !focused}
				<p>Click the game to enable keys</p>
				<p />
			{/if}
		</Debugger>

		<nav id="button-row">
			{#if debug}
				<button
					transition:fade
					class="btn"
					on:pointerdown={startHold}
					on:pointerup={endHold}
					on:keydown={startHold}
					on:keyup={endHold}>Step over</button
				>
				<button transition:fade class="btn" on:click={() => (debug = false)}>Stop</button>
			{:else if paused}
				<button transition:fade class="btn" on:click={toggleDebug}>
					{debug ? 'Stop' : 'Debug'}
				</button>
			{/if}
		</nav>
		<p>Paused: {paused}</p>
		<p>debug: {debug}</p>
	</div>
{:catch err}
	<p>Some error: {err}</p>
{/await}

<style>
	#work-area {
		width: 100%;
		height: 100%;
	}
</style>
