import { Miniflare } from "miniflare";
import fs from 'fs/promises';

const mf = new Miniflare({
    scriptRequired: false,
    r2Persist: true,
});

const bucket = await mf.getR2Bucket('chip-8');

const games = await fs.readdir('tests/games');
console.log('Seeding games: ')
await Promise.all(
    games.map(async (gameFile) => {
        const gameData = await fs.readFile(`tests/games/${gameFile}`);
        console.info(` - ${gameFile}`);
        return await bucket.put(gameFile, gameData.buffer);
    })
);
console.info(`Finished seeding! ✅`)