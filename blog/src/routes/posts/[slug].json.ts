import fs from 'fs/promises';
import matter from 'gray-matter';
import type { PostFrontmatter } from './post';
import type { RequestHandler } from './__types/[slug].json';

export const GET: RequestHandler<PostFrontmatter> = async ({ params }) => {
  try {
    const contents = await fs.readFile(`src/routes/posts/${params.slug}.md`, 'utf-8');
    const { data: metadata } = matter(contents);
    return {
      status: 200,
      body: metadata as PostFrontmatter,
    };
  } catch (err) {
    console.error(err);
  }
  return { status: 404 };
}