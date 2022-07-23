import { Miniflare } from 'miniflare'

const mf = new Miniflare({
    scriptRequired: false,
    modules: true,
    envPath: true,
    packagePath: true,
    wranglerConfigPath: true,
    watch: true
});

const env = await mf.getBindings();
env['chip-8'] = await mf.getR2Bucket('chip-8');
// @ts-expect-error
export const miniflarePlatform: App.Platform = { env };