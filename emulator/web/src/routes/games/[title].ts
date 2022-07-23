import type { RequestEvent, RequestHandlerOutput } from "@sveltejs/kit";
import fs from 'fs/promises';
import path from 'path';

export async function GET(event: RequestEvent): Promise<RequestHandlerOutput> {
    const data = await fs.readFile(path.resolve(`./static/c8/${event.params.title}`))
    return {
        headers: {
            'Content-Type': 'application/octet-stream'
        },
        body: new Uint8Array(data)
    }
}