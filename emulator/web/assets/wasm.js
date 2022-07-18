'use strict';

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

const TOP_LEFT_X = 10;
const TOP_LEFT_Y = 10;

const PIXEL_SIZE = 5;

function* pixelPos() {
  for (let y = 0; y < 32; y++) {
    for (let x = 0; x < 64; x++) {
      yield [x, y];
    }
  }
}

function* bitsOf(num) {
    for (let i = 7; i >= 0; i--) {
      const masked = num & (1 << i);
      yield masked ? 1 : 0;
    }
}


const canvas = document.getElementById("emulator-screen");
const ctx = canvas.getContext('2d');
function draw(location, size) {
  const buffer = new Uint8Array(instance.exports.memory.buffer, location, size);
  const pos = pixelPos();

  for(let _byte of buffer.values()) {
    console.log(_byte.toString(2));
    for (let bit of bitsOf(_byte)) {
      const [x, y] = pos.next().value;

      console.log(x, y);
      console.log(bit);
      ctx.fillStyle = bit === 1 ? 'white' : 'black';
      const pixelX = TOP_LEFT_X + PIXEL_SIZE * x;
      const pixelY = TOP_LEFT_Y + PIXEL_SIZE * y;
      ctx.fillRect(pixelX, pixelY, pixelX + PIXEL_SIZE, pixelY + PIXEL_SIZE);
    }
  }
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
const game = new Uint8Array(instance.exports.memory.buffer, 0, 5);
game.set([1, 2, 3, 0, 1]);
instance.exports.init(getRandomSeed(), performance.now(), 500, game.byteOffset, game.length);

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
