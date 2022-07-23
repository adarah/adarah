import type { Handle } from '@sveltejs/kit'
import { miniflarePlatform } from './miniflare/platform';

export const handle: Handle = async ({ event, resolve }) => {
    if (import.meta.env.DEV) {
        event.platform = miniflarePlatform;
    }
    return resolve(event);
}