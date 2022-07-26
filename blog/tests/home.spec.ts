import { expect, test } from '@playwright/test';

test.describe('homepage', () => {
	test.beforeEach(async ({ page }) => {
		await page.goto('/');
	})

	test('homepage has expected title, h1, and description', async ({ page }) => {
		expect(await page.textContent('h1')).toBe("Lucas Harada's blog");
		expect(await page.textContent('h2')).toBe('A place for me to write down ideas, lessons, and whatever comes to mind.');
		expect(await page.title()).toBe("Home | Lucas Harada's blog")
	});

	test('homepage has a picture', async ({ page }) => {
		expect(await page.locator('figure').count()).toBe(1);
		expect(await page.locator('img').count()).toBe(1);
		expect(await page.locator('figcaption').count()).toBe(1);
	})
})