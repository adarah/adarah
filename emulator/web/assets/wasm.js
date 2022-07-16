let instance;

function consoleLog(location, size) {
    const buffer = new Uint8Array(instance.exports.memory.buffer, location, size);
    const decoder = new TextDecoder();
    const string = decoder.decode(buffer);
    console.log(string);
}

const imports = {
    env: {
        consoleLog
    },
}

WebAssembly.instantiateStreaming(fetch('/static/chip-8.wasm'), imports)
    .then(obj => {
        instance = obj.instance;
        const fromZig = obj.instance.exports.add(1, 2);
        console.log(fromZig);
    });
