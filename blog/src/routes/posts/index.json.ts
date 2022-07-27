import type { RequestHandler } from './__types/index.json';

export interface Article {
  title: string
  path: string
  date: string
};

export const GET: RequestHandler<Article[]> = async () => {
  const markdownFiles = import.meta.glob('./*.md');
  const proms = Object.entries(markdownFiles).map(async ([path, module]) => {
    const { metadata } = await module() as { metadata: Article };
    // removes "./"" from the start, and ".md" from the end
    metadata.path = '/posts/' + path.slice(2, -3);
    return metadata;
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