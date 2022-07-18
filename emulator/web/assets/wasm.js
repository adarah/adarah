function consoleLog(location, size) {
  const buffer = new Uint8Array(instance.exports.memory.buffer, location, size);
  const decoder = new TextDecoder();
  const string = decoder.decode(buffer);
  console.log(string);
}

function consoleError(location, size) {
  const buffer = new Uint8Array(instance.exports.memory.buffer, location, size);
  const decoder = new TextDecoder();
  const string = decoder.decode(buffer);
  console.error(string);
}

function getRandomSeed() {
  return Math.floor(Math.random() * 2147483647);
}

const canvas = document.getElementById("emulator-screen");
function draw(location, size) {
  const buffer = new Uint8Array(instance.exports.memory.buffer, location, size);
  console.log(buffer);
}

const imports = {
    env: {
      consoleLog,
      consoleError,
      getRandomSeed,
      draw,
    },
}

const obj = await WebAssembly.instantiateStreaming(fetch('/static/chip-8.wasm'), imports)

let instance = obj.instance;
instance.exports.init(500, performance.now());

// Setup key handlers
document.addEventListener('keydown', event => {
  instance.exports.onKeydown(event.key.codePointAt());
});
document.addEventListener('keyup', event => {
  instance.exports.onKeyup(event.key.codePointAt());
});

const step = (now) => {
  instance.exports.onAnimationFrame(now);
  window.requestAnimationFrame(step);
}
window.requestAnimationFrame(step);

// Setup timers
setInterval(() => instance.exports.timerTick(), 16.67)

// const fromZig = instance.exports.add(1, 2);
// console.log(fromZig);

// instance.exports.waitForKey();
// instance.exports.waitForKey();
