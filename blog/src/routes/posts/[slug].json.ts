import fs from 'fs/promises';
import { compile } from 'mdsvex';
import mdsvexConfig from '../../../mdsvex.config';
import type { Post } from './post';
import type { RequestHandler } from './__types/[slug].json';

export const GET: RequestHandler<Post> = async ({ params }) => {
  try {
    const contents = await fs.readFile(`src/routes/posts/${params.slug}.md`, 'utf-8');
    const parsed = await compile(contents, mdsvexConfig);
    if (parsed?.data?.fm === undefined) {
      throw Error('article not found');
    }
    const post = parsed.data.fm as Post;
    return {
      status: 200,
      body: post,
    };
  } catch (err) {
    console.error(err);
  }
  return { status: 404 };
}