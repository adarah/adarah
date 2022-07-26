import { expect, type Locator, test } from '@playwright/test';

test.describe('layout', () => {
  test('uses flebox', async ({ page }) => {
    const root = page.locator('data-testid=root');
    expect(root).toHaveCSS('display', 'flex');
  });

  test('has a main tag which wraps slots', async ({ page }) => {
    const main = page.locator('main');
    expect(main).toHaveCount(1);
    // TODO: Figure out how to write a test to check if the main tag actually wraps the page's contents
  });

  test.describe('sidebar', () => {
    let sidebar: Locator;
    test.beforeEach(async ({ page }) => {
      sidebar = page.locator('data-testid=sidebar');
    });

    test('has a picture, name and current job', async () => {
      await expect(sidebar.locator('img')).toHaveCount(1);
      await expect(sidebar.locator('"Lucas Harada"')).toHaveCount(1);
      await expect(sidebar.locator('"Software Engineer @"')).toHaveCount(1);
    });

    test('has nav links', async () => {
      const nav = sidebar.locator('nav');
      await expect(nav).toBeVisible();

      const links = nav.locator('a');
      await expect(links).toHaveCount(4);
      await expect(links.locator('"Home"')).toBeVisible();
      await expect(links.locator('"Posts"')).toBeVisible();
      await expect(links.locator('"Projects"')).toBeVisible();
      await expect(links.locator('"Resume"')).toBeVisible();
    });

    test('has contact info', async () => {
      const address = sidebar.locator('address');
      await expect(address.locator('a')).toHaveCount(4);
      await expect(address.locator('"Lucas Harada"')).toBeVisible();
      await expect(address.locator('"+55"')).toBeVisible();
      await expect(address.locator('"@gmail.com"')).toBeVisible();
      await expect(address.locator('"adarah"')).toBeVisible();
    });

    test('minimizes when pressing the arrow button', async () => {
      const minizeButton = sidebar.locator('"◀"');
      await expect(minizeButton).toBeVisible();

      minizeButton.click();

      // Minimizing should hide all images and links
      await expect(sidebar.locator('img')).toBeEmpty();
      await expect(sidebar.locator('nav')).toBeEmpty();
      await expect(sidebar.locator('address')).toBeEmpty();

      // But not the button to expand the sidebar
      await expect(minizeButton).toBeVisible();
      await expect(minizeButton).toHaveText('▶');
    });
  });
});
