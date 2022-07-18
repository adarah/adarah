import {draw as canvasDraw} from './canvas.js';

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

function draw(location, size) {
  const buffer = new Uint8Array(instance.exports.memory.buffer, location, size);
  canvasDraw(buffer);
}

function setStack(SP, location, size) {
  const stack = document.getElementById("stack");
  console.log('set stack!');

  const buffer = new Uint8Array(instance.exports.memory.buffer, location, size);
  let msg = `SP: ${SP.toString(16)}\nstack: `;
  for (let b of buffer) {
    msg += ` ${b.toString(16)} |`;
  }
  stack.innerText = msg;
}

function setRegisters(PC, location, size) {
  const registers = document.getElementById("registers");
  console.log('set registers!');

  const buffer = new Uint8Array(instance.exports.memory.buffer, location, size);
  let msg = `PC: ${PC.toString(16)}\nregisters: `;
  for (let b of buffer) {
    msg += ` ${b.toString(16)} |`;
  }
  registers.innerText = msg;
}

const imports = {
    env: {
      consoleLog,
      consoleError,
      getRandomSeed,
      draw,
      setStack,
      setRegisters,
    },
}

const gameRes = await fetch('/static/games/test_ROMs/BC_test.ch8');
const buffer = new Uint8Array(await gameRes.arrayBuffer());

const obj = await WebAssembly.instantiateStreaming(fetch('/static/chip-8.wasm'), imports)

let instance = obj.instance;
const game = new Uint8Array(instance.exports.memory.buffer, 0, buffer.length);
game.set(buffer);

instance.exports.init(getRandomSeed(), performance.now(), 500, game.byteOffset, buffer.length);

// Setup key handlers
document.addEventListener('keydown', event => {
  instance.exports.onKeydown(event.key.codePointAt());
});
document.addEventListener('keyup', event => {
  instance.exports.onKeyup(event.key.codePointAt());
});

// Setup timers
setInterval(() => instance.exports.timerTick(), 16.67)

document.getElementById('step-button').addEventListener('click', () => {
  instance.exports.debugStep();
});

const step = (now) => {
  instance.exports.onAnimationFrame(now);
  window.requestAnimationFrame(step);
}
window.requestAnimationFrame(step);

