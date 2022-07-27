import type { RequestHandler } from './__types/list';
import glob from 'glob';
import path from 'path';
import fs from 'fs/promises';
import { compile } from 'mdsvex';
import mdsvexConfig from '../../../mdsvex.config';

export interface Article {
  title: string
  path: string
  date: string
};

export const GET: RequestHandler<Article[]> = async () => {
  const basePath = 'src/routes/posts';
  const markdownFiles = glob.sync(`${basePath}/**/*.md`);
  const proms = markdownFiles.map(async f => {
    const contents = await fs.readFile(f, 'utf-8');
    const parsed = await compile(contents, mdsvexConfig);
    if (parsed?.data?.fm !== undefined) {
      const metadata = parsed.data.fm as Article;
      // slice(0, -3) remove the .md file extension
      const relPath = path.relative(basePath, f).slice(0, -3);
      metadata.path = '/posts/' + relPath;
      return metadata;
    }
  })
  const parsedEntries = await Promise.all(proms);
  const articles: Article[] = parsedEntries.filter((a): a is Article => a !== undefined);
  // Sort by date desc
  articles.sort((a, b) => Date.parse(b.date) - Date.parse(a.date));
  return {
    status: 200,
    body: articles
  }
}