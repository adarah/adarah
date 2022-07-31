import { expect, type Locator, test } from '@playwright/test';

test.describe('posts', () => {
  test.describe('index', () => {
    test('shows posts ordered by date descending', () => {

    });

    test('shows title, description, and date of posts', () => {

    });

    test('has a search bar', () => {

    });
  });

  const posts = ['/posts/01-first-post'];
  for (const p of posts) {
    test.describe(`${p}`, () => {
      test('sets SEO tags', () => {

      });
    });
  }
});