import fs from 'fs/promises';
import matter from 'gray-matter';
import path from 'path';
import type { RequestHandler } from './__types/index.json';

export interface Article {
  title: string
  path: string
  excerpt: string
  date: string
};

export const GET: RequestHandler<Article[]> = async () => {
  const postsPath = 'src/routes/posts'
  const files = await fs.readdir(postsPath);
  const markdownFiles = files.filter(f => path.extname(f) === '.md');
  const proms = markdownFiles.map(async (f) => {
    const contents = await fs.readFile(`${postsPath}/${f}`, 'utf-8');
    const parsed = matter(contents, { excerpt: true });
    return {
      ...parsed.data,
      excerpt: parsed.excerpt,
      // removes ".md" from the end
      path: '/posts/' + f.slice(0, -3)
    };
  });
  const parsedEntries = await Promise.all(proms);
  const articles: Article[] = parsedEntries.filter((a): a is Article => a !== undefined);
  // Sort by date desc
  articles.sort((a, b) => Date.parse(b.date) - Date.parse(a.date));
  return {
    status: 200,
    body: articles
  }
}