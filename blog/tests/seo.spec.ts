import { expect, test } from '@playwright/test';

test.describe('seo', () => {
  test.skip('sets default tags', async ({ page }) => {
    await page.goto('/');

    await expect(page.locator('link[rel=canonical]')).toHaveCount(1);
    await expect(page.locator('og:title')).toHaveAttribute('content', "Lucas Harada's blog");
    await expect(page.locator('og:type')).toHaveAttribute('content', 'website');
    await expect(page.locator('og:locale')).toHaveAttribute('content', 'en-US');
  })
})