import type { RequestHandler } from './__types/list';
import glob from 'glob';
import path from 'path';
import fs from 'fs/promises';
import { compile } from 'mdsvex';
import mdsvexConfig from '../../../mdsvex.config';

export interface Article {
  title: string
  slug: string
  date: string
};

export const GET: RequestHandler<Article[]> = async () => {
  const markdownFiles = glob.sync('src/routes/posts/*.md');
  const proms = markdownFiles.map(async f => {
    const contents = await fs.readFile(f, 'utf-8');
    const parsed = await compile(contents, mdsvexConfig);
    if (parsed?.data?.fm !== undefined) {
      const metadata = parsed.data.fm as Record<string, unknown>;
      metadata.slug = '/posts/' + path.basename(f, '.md');
      return metadata;
    }
  })
  // @ts-expect-error
  const articles: Article[] = await Promise.all(proms);
  console.log('invoked')
  return {
    status: 200,
    body: articles
  }
}