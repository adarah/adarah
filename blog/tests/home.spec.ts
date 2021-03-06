import { expect, test } from '@playwright/test';

test.describe('homepage', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('has expected title, h1, and description', async ({ page }) => {
    await expect(page).toHaveTitle("Home | Lucas Harada's blog");
    await expect(page.locator('"Welcome to my blog!"')).toBeVisible();
    await expect(page.locator('p')).toBeVisible();
  });

  test('has a picture', async ({ page }) => {
    const homePicture = page.locator('figure');
    await expect(homePicture).toBeVisible();
    await expect(homePicture.locator('img')).toBeVisible();

    const caption = homePicture.locator('figcaption');
    await expect(caption).toHaveCSS('font-style', 'italic');
    await expect(caption).toBeVisible();
  });
});
