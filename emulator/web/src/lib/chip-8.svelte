<script lang="ts" context="module">
	export interface Chip8Quirks {
		shift: boolean;
		register: boolean;
		wrap: boolean;
	}

	let instance: WebAssembly.Instance
    let memory: WebAssembly.Memory

	function getString(location: number, size: number): string {
		const buffer = new Uint8Array(memory.buffer, location, size);
		const decoder = new TextDecoder();
		return decoder.decode(buffer);
	}

	function consoleDebug(location: number, size: number): void {
		const string = getString(location, size);
		console.debug(string);
	}

	function consoleInfo(location: number, size: number) {
		const string = getString(location, size);
		console.info(string);
	}

	function consoleWarn(location: number, size: number): void {
		const string = getString(location, size);
		console.warn(string);
	}

	function consoleError(location: number, size: number): void {
		const string = getString(location, size);
		console.error(string);
	}

	function setStack(location: number, size: number) {
		const stack = document.getElementById('stack');

		const buffer = new Uint8Array(memory.buffer, location, size);
		let msg = `stack: `;
		for (let b of buffer) {
			msg += ` ${b.toString(16)} |`;
		}
		stack.innerText = msg;
	}

	function setRegisters(PC: number, SP: number, I: number, location: number, size: number): void {
		const registers = document.getElementById('registers');

		const buffer = new Uint8Array(memory.buffer, location, size);
		let msg = `PC: ${PC.toString(16)}\nregisters: `;
		for (let b of buffer) {
			msg += ` ${b.toString(16)} |`;
		}
		registers.innerText = msg;
	}

	function setMem(location: number, size: number): void{
		const buffer = new Uint8Array(memory.buffer, location, size);
	}

	const imports = {
		env: {
			consoleDebug,
			consoleInfo,
			consoleWarn,
			consoleError,
            setStack,
            setRegisters,
		}
	};
</script>

<script lang="ts">
	import { onMount } from 'svelte/types/runtime/internal/lifecycle';
	export let seed: number = Math.floor(Math.random() * 2147483647);
	export let clockFrequencyHz: number = 500;
	export let quirks: Chip8Quirks = {
		shift: true,
		register: true,
		wrap: true
	};
	export let game: Uint8Array;

	onMount(async () => {
		const obj = await WebAssembly.instantiateStreaming(fetch('/static/chip-8.wasm'), imports);
		instance = obj.instance;
        memory = instance.exports.memory as WebAssembly.Memory
	});
</script>

<canvas />
<div>
	{seed}
	{clockFrequencyHz}
	{quirks}
</div>
