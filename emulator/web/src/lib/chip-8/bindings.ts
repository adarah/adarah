export function genEnv(memory: WebAssembly.Memory): WebAssembly.ModuleImports {
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

    const setStack = (offset: number, length: number): void => {
        const buffer = new Uint8Array(memory.buffer, offset, length);
    }

    const setRegisters = (PC: number, SP: number, I: number, offset: number, length: number): void => {
        const buffer = new Uint8Array(memory.buffer, offset, length);
    }

    const setMem = (offset: number, length: number): void => {
        const buffer = new Uint8Array(memory.buffer, offset, length);
    }

    return {
        consoleDebug,
        consoleInfo,
        consoleWarn,
        consoleError,
        setStack,
        setRegisters,
        setMem,
        memory
    };
}

