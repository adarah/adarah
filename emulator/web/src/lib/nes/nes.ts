interface NesExports {
  main: () => void;
}

interface NesOptions {
  code: Promise<Response>
}

export class Nes {
  private readonly exports: NesExports;

  public static async init(options: NesOptions): Promise<Nes> {
    // These are the number of pages allocated to the binary. Each page has 64KiB
    let memory = new WebAssembly.Memory({ initial: 2, maximum: 2 });

    const imports = {
      env: Nes.genBindings(memory)
    };

    const source = await WebAssembly.instantiateStreaming(options.code, imports);
    const exports = source.instance.exports as unknown as NesExports;
    return new Nes(exports);
  }

  public main(): void {
    this.exports.main();
  }

  private constructor(exports: NesExports) {
    this.exports = exports;
  }

  private static genBindings(memory: WebAssembly.Memory): WebAssembly.ModuleImports {
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

    return {
      consoleDebug,
      consoleInfo,
      consoleWarn,
      consoleError,
      memory
    };
  }
}