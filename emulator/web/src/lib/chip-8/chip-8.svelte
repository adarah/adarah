<script lang="ts">
	import Canvas from './canvas.svelte';
	import { Chip8, type Chip8Quirks } from './chip-8';

	export let gameData: Promise<Uint8Array>;
	export let seed: number;
	export let clockFrequencyHz: number;
	export let quirks: Chip8Quirks;
	export let audio: HTMLAudioElement = new Audio('/oof.mp3');

	// Emulation values
	let chip8: Chip8;
	let PC: number;
	let SP: number;
	let registers: Uint8Array;
	let stack: Uint16Array;
	let paused: boolean = true;

	// Timers
	let animationFrame: number;
	let timerInterval: ReturnType<typeof setInterval>;
	
	$: resetAndLoad(gameData);

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
		enableTimers();
	}

	function enableTimers() {
		timerInterval = setInterval(() => chip8.timerTick(), 16.667);
		return () => clearInterval(timerInterval);
	}

	async function resetAndLoad(gameData: Promise<Uint8Array>) {
		chip8.reset();
		const game = await gameData;
		chip8.loadGame(game);
	}

	function play(): void {
		function loop(): void {
			chip8.step();
			animationFrame = requestAnimationFrame(loop);
			PC = chip8.PC;
			SP = chip8.SP;
			registers = chip8.registers;
			stack = chip8.stack;
		}
		chip8.resume();
		enableTimers();
		animationFrame = requestAnimationFrame(loop);
		paused = false;
	}

	function pause(): void {
		cancelAnimationFrame(animationFrame);
		clearInterval(timerInterval);
		paused = true;
	}

	function toggle(): void {
		if (paused) {
			play();
		} else {
			pause();
		}
	}
</script>

{#await init()}
	<p>Loading...</p>
{:then}
	<Canvas
		pixelSize={20}
		buffer={chip8.display}
		on:keydown={(e) => chip8.onKeydown(e.key)}
		on:keyup={(e) => chip8.onKeyup(e.key)}
		on:focus={play}
		on:blur={pause}
	/>
	<button on:click={toggle}>{paused ? 'Play' : 'Pause'}</button>

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
