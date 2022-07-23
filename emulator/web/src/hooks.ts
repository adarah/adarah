import type { Handle } from '@sveltejs/kit'

export const handle: Handle = async ({ event, resolve }) => {
    if (import.meta.env.DEV) {
        const { miniflarePlatform } = await import('./miniflare/platform');
        event.platform = miniflarePlatform;
    }
    return resolve(event);
}