<script lang="ts">
	import { onMount } from 'svelte';
	import { fade } from 'svelte/transition';
	let canvas: HTMLCanvasElement;
	let gl: WebGL2RenderingContext;
	let vertexBuffer: WebGLBuffer;
	let elementBuffer: WebGLBuffer;
	let textures: WebGLTexture[] = [];
	let shaders: WebGLShader[] = [];
	let program: WebGLProgram;
	let uniforms: Record<string, WebGLUniformLocation | null>;
	let attributes: Record<string, number>;
	let fadeFactor: number = 0.5;
	let prevTime: DOMHighResTimeStamp = performance.now();

	onMount(async () => {
		await main();
		function loop() {
			render();
			updateFadeFactor();
			requestAnimationFrame(loop);
		}
		requestAnimationFrame(loop);
	});

	async function main(): Promise<void> {
		const ctx = canvas.getContext('webgl2');
		// Only continue if WebGL is available and working
		if (ctx === null) {
			alert('Unable to initialize WebGL 2.0. Your browser or machine may not support it.');
			return;
		}
		gl = ctx;

		gl.clearColor(1.0, 1.0, 1.0, 1.0);
		// Clear the color buffer with specified clear color
		gl.clear(gl.COLOR_BUFFER_BIT);

		await makeResources();
	}

	function render(): void {
		gl.useProgram(program);
		gl.uniform1f(uniforms.fadeFactor, fadeFactor);

		gl.activeTexture(gl.TEXTURE0);
		gl.bindTexture(gl.TEXTURE_2D, textures[0]);
		gl.uniform1i(uniforms.texture0, 0);

		gl.activeTexture(gl.TEXTURE1);
		gl.bindTexture(gl.TEXTURE_2D, textures[1]);
		gl.uniform1i(uniforms.texture1, 1);

		gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer);
		// Float32 takes 4 bytes, and we want to skip over 2 of them
		gl.vertexAttribPointer(attributes.position, 2, gl.FLOAT, false, 4 * 2, 0);
		gl.enableVertexAttribArray(attributes.position);

		gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, elementBuffer);
		gl.drawElements(gl.TRIANGLE_STRIP, 4, gl.UNSIGNED_SHORT, 0);

		// Cleanup
		gl.disableVertexAttribArray(attributes.position);
	}

	function updateFadeFactor() {
		const now = performance.now();
		const elapsed = prevTime - performance.now();
		fadeFactor = Math.sin(elapsed * 0.1) * 0.5 + 0.5;
		prevTime = now;
	}

	async function makeResources(): Promise<void> {
		const glVertexBufferData = new Float32Array([-1.0, -1.0, 1.0, -1.0, -1.0, 1.0, 1.0, 1.0]);
		const glElementBufferData = new Uint16Array([0, 1, 2, 3]);
		vertexBuffer = makeBuffer(gl.ARRAY_BUFFER, glVertexBufferData);
		elementBuffer = makeBuffer(gl.ELEMENT_ARRAY_BUFFER, glElementBufferData);

		textures = await Promise.all([makeTexture('/hello1.tga'), makeTexture('/hello2.tga')]);
		shaders = await Promise.all([
			makeShader('/hello-gl.vert', gl.VERTEX_SHADER),
			makeShader('/hello-gl.frag', gl.FRAGMENT_SHADER)
		]);
		program = makeProgram();

		const fadeFactor = gl.getUniformLocation(program, 'fade_factor');
		const texture0 = gl.getUniformLocation(program, 'textures[0]');
		const texture1 = gl.getUniformLocation(program, 'textures[1]');
		uniforms = {
			fadeFactor,
			texture0,
			texture1
		};
		attributes = {
			position: gl.getAttribLocation(program, 'position')
		};
	}

	function makeBuffer(target: number, bufferData: ArrayBufferView): WebGLBuffer {
		const buf = gl.createBuffer();
		if (buf === null) {
			throw Error('failed to created buffer');
		}
		gl.bindBuffer(target, buf);
		gl.bufferData(target, bufferData, gl.STATIC_DRAW);
		return buf;
	}

	interface TgaFile {
		data: Uint8Array;
		width: number;
		height: number;
	}
	async function readTga(filename: string): Promise<TgaFile> {
		const buf = await fetch(filename)
			.then((r) => r.arrayBuffer())
			.then((a) => new Uint8Array(a));
		// Tga stores data in little endian
		const width = (buf[13] << 8) + buf[12];
		const height = (buf[15] << 8) + buf[14];
		const data = buf.slice(18);
		// Transform BGR to RGB
		for (let i = 0; i < data.length; i++) {
			const tmp = data[i];
			data[i] = data[i + 2];
			data[i + 2] = tmp;
		}
		return { data, width, height };
	}

	async function makeTexture(filename: string): Promise<WebGLTexture> {
		const f = await readTga(filename);
		const texture = gl.createTexture();
		if (texture === null) {
			throw Error('failed to create texture');
		}
		gl.bindTexture(gl.TEXTURE_2D, texture);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
		gl.texImage2D(
			gl.TEXTURE_2D,
			0,
			gl.RGB8,
			f.width,
			f.height,
			0,
			gl.RGB,
			gl.UNSIGNED_BYTE,
			f.data
		);
		return texture;
	}

	async function makeShader(filename: string, type: number): Promise<WebGLShader> {
		const shaderSource = await fetch(filename).then((r) => r.text());
		const shader = gl.createShader(type);
		if (shader === null) {
			throw Error('failed to create shader');
		}
		gl.shaderSource(shader, shaderSource);
		gl.compileShader(shader);
		const msg = gl.getShaderInfoLog(shader);
		if (msg === null || msg.length > 0) {
			throw Error(msg ?? 'No shader info log');
		}
		return shader;
	}

	function makeProgram(): WebGLProgram {
		const program = gl.createProgram();
		if (program === null) {
			throw Error('failed to create program');
		}
		shaders.forEach((s) => gl.attachShader(program, s));
		gl.linkProgram(program);
		const msg = gl.getProgramInfoLog(program);
		if (msg === null || msg.length > 0) {
			throw Error(msg ?? 'No program info log');
		}
		return program;
	}
</script>

<canvas bind:this={canvas} id="glCanvas" width="640" height="480" />

<style>
	#glCanvas {
		border: solid 1px black;
	}
</style>
