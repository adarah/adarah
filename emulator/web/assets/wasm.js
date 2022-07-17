let instance;
let keyboard;

function consoleLog(location, size) {
    const buffer = new Uint8Array(instance.exports.memory.buffer, location, size);
    const decoder = new TextDecoder();
    const string = decoder.decode(buffer);
    console.log(string);
}

function getRandomSeed() {
  return Math.floor(Math.random() * 2147483647);
}


const imports = {
    env: {
      consoleLog,
      getRandomSeed,
    },
}

WebAssembly.instantiateStreaming(fetch('/static/chip-8.wasm'), imports)
    .then(obj => {
        instance = obj.instance;
        document.addEventListener('keydown', event => {
          instance.exports.onKeydown(event.key.codePointAt());
        })
        document.addEventListener('keyup', event => {
          instance.exports.onKeyup(event.key.codePointAt());
        })

        const fromZig = obj.instance.exports.add(1, 2);
        console.log(fromZig);
    });
