export class Chip8Memory {
    static readonly PC_OFFSET = 0x50;
    static readonly SP_OFFSET = 0x52;
    static readonly I_OFFSET = 0x54;
    static readonly STACK_OFFSET = 0xEA0;
    static readonly STACK_SIZE = 0x30;
    static readonly REGISTERS_OFFSET = 0xEF0;
    static readonly REGISTERS_SIZE = 0x10;
    static readonly DISPLAY_OFFSET = 0xF00;
    static readonly DISPLAY_SIZE = 0x100;

    public readonly array: Uint8Array;
    private readonly baseOffset: number;

    constructor(buffer: ArrayBuffer, offset: number) {
        this.array = new Uint8Array(buffer, offset, 4096);
        this.baseOffset = offset;
    }

    private getWord(offset: number) {
        const msb = this.array[this.baseOffset + offset];
        const lsb = this.array[this.baseOffset + offset + 1]
        return msb << 8 + lsb;
    }

    get PC(): number {
        return this.getWord(this.baseOffset + Chip8Memory.PC_OFFSET)
    }

    get SP(): number {
        return this.getWord(this.baseOffset + Chip8Memory.SP_OFFSET);
    }

    get I(): number {
        return this.getWord(this.baseOffset + Chip8Memory.I_OFFSET);
    }

    get stack(): Uint16Array {
        return new Uint16Array(this.array.buffer, this.baseOffset + Chip8Memory.STACK_OFFSET, Chip8Memory.STACK_SIZE);
    }

    get registers(): Uint8Array {
        return new Uint8Array(this.array.buffer, this.baseOffset + Chip8Memory.REGISTERS_OFFSET, Chip8Memory.REGISTERS_SIZE);
    }

    get display(): Uint8Array {
        return new Uint8Array(this.array.buffer, this.baseOffset + Chip8Memory.DISPLAY_OFFSET, Chip8Memory.DISPLAY_SIZE);
    }
}