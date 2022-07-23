export interface Chip8Quirks {
    shift: boolean;
    register: boolean;
    wrap: boolean;
}

export interface Chip8Options {
    code: Promise<Response>;
    audio: HTMLAudioElement;
    seed?: number;
    clockFrequencyHz?: number;
    quirks?: Chip8Quirks;
}

interface Chip8Exports {
    init(
        seed: number,
        startTime: number,
        clockFrequencyHz: number,
        shiftQuirk: boolean,
        registerQuirk: boolean,
    ): void;
    reset(): void;
    loadGame(gameData: number, gameLength: number): void;
    getMemPtr(): number;
    onKeydown(keycode: number): void;
    onKeyup(keycode: number): void;
    onAnimationFrame(time: DOMHighResTimeStamp): void;
    timerTick(): void;
    getSoundTimer(): number;
    setCurrentTime(now: DOMHighResTimeStamp): void;
    debugStep(): void;
}

export class Chip8 {
    private static readonly PC_OFFSET = 0x50;
    private static readonly SP_OFFSET = 0x52;
    private static readonly I_OFFSET = 0x54;
    private static readonly STACK_OFFSET = 0xEA0;
    private static readonly STACK_SIZE = 0x30;
    private static readonly REGISTERS_OFFSET = 0xEF0;
    private static readonly REGISTERS_SIZE = 0x10;
    private static readonly DISPLAY_OFFSET = 0xF00;
    private static readonly DISPLAY_SIZE = 0x100;

    public readonly array: Uint8Array;

    private readonly baseOffset: number;
    private readonly exports: Chip8Exports;

    public static async init(options: Chip8Options): Promise<Chip8> {
        const seed = options.seed ?? Chip8.getRandomSeed();
        const clockFrequencyHz = options.clockFrequencyHz ?? 500;
        const quirks = options.quirks ?? { shift: true, register: true, wrap: true };

        // These are the number of pages allocated to the binary. Each page has 64KiB
        let memory = new WebAssembly.Memory({ initial: 2, maximum: 2 });

        const imports = {
            env: Chip8.genBindings(memory, options.audio)
        };

        const source = await WebAssembly.instantiateStreaming(options.code, imports);
        const exports = source.instance.exports as unknown as Chip8Exports;
        exports.init(
            seed,
            performance.now(),
            clockFrequencyHz,
            quirks.shift,
            quirks.register,
        );
        const memPtr: number = exports.getMemPtr();
        return new Chip8(exports, memory.buffer, memPtr);
    }

    public async loadGame(gameData: Uint8Array): Promise<void> {
        const mainMem = new Uint8Array(this.array.buffer, 0, gameData.length);
        mainMem.set(gameData);
        this.exports.loadGame(mainMem.byteOffset, mainMem.length);
    }

    public reset(): void {
        this.exports.reset();
    }

    public resume(): void {
        this.exports.setCurrentTime(performance.now());
    }

    // Executes as many instructions as needed to simulate the clock speed
    public step(): void {
        this.exports.onAnimationFrame(performance.now());
    }

    // Executes a single instruction
    public debugStep(): void {
        this.exports.debugStep();
    }

    // Tick down timers.
    // Cpu speed may vary according to config, but timers are always 60Hz
    public timerTick(): void {
        this.exports.timerTick();
    }

    public onKeydown(key: string): void {
        const numpadKey = this.asciiToKeypad(key);
        if (numpadKey === null) {
            return;
        }
        this.exports.onKeydown(numpadKey);
    }

    public onKeyup(key: string): void {
        const numpadKey = this.asciiToKeypad(key);
        if (numpadKey === null) {
            return;
        }
        this.exports.onKeyup(numpadKey);
    }

    get PC(): number {
        return this.getWord(Chip8.PC_OFFSET)
    }

    get SP(): number {
        return this.getWord(Chip8.SP_OFFSET);
    }

    get I(): number {
        return this.getWord(Chip8.I_OFFSET);
    }

    get stack(): Uint16Array {
        return new Uint16Array(this.array.buffer, this.baseOffset + Chip8.STACK_OFFSET, Chip8.STACK_SIZE / 2);
    }

    get registers(): Uint8Array {
        return new Uint8Array(this.array.buffer, this.baseOffset + Chip8.REGISTERS_OFFSET, Chip8.REGISTERS_SIZE);
    }

    get display(): Uint8Array {
        return new Uint8Array(this.array.buffer, this.baseOffset + Chip8.DISPLAY_OFFSET, Chip8.DISPLAY_SIZE);
    }

    private constructor(exports: Chip8Exports, buffer: ArrayBuffer, offset: number) {
        this.exports = exports;
        this.baseOffset = offset;
        this.array = new Uint8Array(buffer, offset, 4096);
    }


    private getWord(offset: number) {
        const msb = this.array[offset];
        const lsb = this.array[offset + 1]
        return msb << 8 + lsb;
    }

    // A chip-8 keypad is a 16 key square, and each key correspond to a hexadecimal value
    // ╔═══╦═══╦═══╦═══╗
    // ║ 1 ║ 2 ║ 3 ║ C ║
    // ╠═══╬═══╬═══╬═══╣
    // ║ 4 ║ 5 ║ 6 ║ D ║
    // ╠═══╬═══╬═══╬═══╣
    // ║ 7 ║ 8 ║ 9 ║ E ║
    // ╠═══╬═══╬═══╬═══╣
    // ║ A ║ 0 ║ B ║ F ║
    // ╚═══╩═══╩═══╩═══╝

    // TODO: Make keybindings configurable
    private asciiToKeypad(key: string): number | null {
        switch (key) {
            case '1': return 0x1;
            case '2': return 0x2;
            case '3': return 0x3;
            case '4': return 0xC;
            case 'q': return 0x4;
            case 'w': return 0x5;
            case 'e': return 0x6;
            case 'r': return 0xD;
            case 'a': return 0x7;
            case 's': return 0x8;
            case 'd': return 0x9;
            case 'f': return 0xE;
            case 'z': return 0xA;
            case 'x': return 0x0;
            case 'b': return 0xB;
            case 'c': return 0xF;
            default: return null
        }
    }

    private static getRandomSeed(): number {
        return Math.floor(Math.random() * 2147483647);
    }

    private static genBindings(memory: WebAssembly.Memory, audio: HTMLAudioElement): WebAssembly.ModuleImports {
        const getString = (offset: number, length: number): string => {
            const buffer = new Uint8Array(memory.buffer, offset, length);
            const decoder = new TextDecoder();
            return decoder.decode(buffer);
        }
        const consoleDebug = (offset: number, length: number): void => {
            const string = getString(offset, length);
            console.debug(string);
        }

        const consoleInfo = (offset: number, length: number) => {
            const string = getString(offset, length);
            console.info(string);
        }

        const consoleWarn = (offset: number, length: number): void => {
            const string = getString(offset, length);
            console.warn(string);
        }

        const consoleError = (offset: number, length: number): void => {
            const string = getString(offset, length);
            console.error(string);
        }

        const playAudio = () => {
            audio.play();
        }

        return {
            consoleDebug,
            consoleInfo,
            consoleWarn,
            consoleError,
            playAudio,
            memory
        };
    }
}