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

const obj = await WebAssembly.instantiateStreaming(fetch('/static/chip-8.wasm'), imports)

let instance = obj.instance;
instance.exports.init();

// Setup key handlers
document.addEventListener('keydown', event => {
  instance.exports.onKeydown(event.key.codePointAt());
});
document.addEventListener('keyup', event => {
  instance.exports.onKeyup(event.key.codePointAt());
});

// Setup timers
setInterval(() => instance.exports.timerTick(), 16.67)

const fromZig = instance.exports.add(1, 2);
console.log(fromZig);

instance.exports.waitForKey();
instance.exports.waitForKey();
