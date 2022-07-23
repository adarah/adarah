import type { RequestHandler } from './__types/[title]'

export const GET: RequestHandler = async ({ platform, params }) => {
    const gameData = await platform.env["chip-8"].get(params.title);
    if (gameData === null) {
        return {
            status: 404,
            headers: {
                'Cache-Control': 'max-age=31536000'
            }
        };
    }
    return {
        headers: {
            'Content-Type': 'application/octet-stream',
            'Cache-Control': 'max-age=31536000'
        },
        body: gameData.body
    }
}