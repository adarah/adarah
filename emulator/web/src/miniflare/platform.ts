import { Miniflare } from 'miniflare'

const mf = new Miniflare({
    scriptRequired: false,
    modules: true,
    envPath: true,
    packagePath: true,
    wranglerConfigPath: true,
    watch: true
});

// await mf.dispatchFetch('http://localhost:6000')
const env = await mf.getBindings();
const bucket = await mf.getR2Bucket('chip-8');
env['chip-8'] = bucket;
await bucket.put('foo', '1234');
// @ts-expect-error
export const miniflarePlatform: App.Platform = { env };