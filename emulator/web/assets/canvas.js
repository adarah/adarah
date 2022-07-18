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
export function draw(buffer) {
  const pos = pixelPos();

  for(let _byte of buffer.values()) {
    for (let bit of bitsOf(_byte)) {
      const [x, y] = pos.next().value;

      ctx.fillStyle = bit === 1 ? 'white' : 'black';
      const pixelX = TOP_LEFT_X + PIXEL_SIZE * x;
      const pixelY = TOP_LEFT_Y + PIXEL_SIZE * y;
      ctx.fillRect(pixelX, pixelY, pixelX + PIXEL_SIZE, pixelY + PIXEL_SIZE);
    }
  }
}
