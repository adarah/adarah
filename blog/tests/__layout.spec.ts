import { expect, type Locator, test } from '@playwright/test';

test.describe('layout', () => {
  const pagesToTest = ['/', '/posts', '/projects', '/resume'];
  for (let p of pagesToTest) {
    test.beforeEach(async ({ page }) => {
      await page.goto(p);
    });

    test(`has a main tag which wraps ${p}'s slots`, async ({ page }) => {
      const main = page.locator('main');
      await expect(main).toHaveCount(1);
      // TODO: Figure out how to write a test to check if the main tag actually wraps the page's contents
    });
  }

  test.describe('sidebar', () => {
    let sidebar: Locator;
    test.beforeEach(async ({ page }) => {
      await page.goto('/');
      sidebar = page.locator('data-testid=sidebar');
    });

    test('has a picture, name and current job', async ({ page }) => {
      await expect(sidebar.locator('img')).toBeVisible();
      await expect(sidebar.locator('h1', { hasText: "Lucas Harada" })).toBeVisible();
      await expect(sidebar.locator('"Software Engineer"')).toBeVisible();
    });

    test('has nav links', async () => {
      const nav = sidebar.locator('nav');
      await expect(nav).toBeVisible();

      const links = nav.locator('a');
      await expect(links).toHaveCount(4);

      const linkMap = {
        Home: '/',
        Posts: '/posts',
        Projects: '/projects',
        Resume: '/resume',
      };
      await Promise.all(
        Object.entries(linkMap).map(async ([name, href]) => {
          const l = links.locator(`text=${name}`);
          await expect(l).toBeVisible();
          await expect(l).toHaveAttribute('href', href);
        })
      )
    });

    test('has contact info', async () => {
      const address = sidebar.locator('address');
      await expect(address.locator('a')).toHaveCount(4);
      await expect(address.locator('"lucas-harada"')).toBeVisible();
      await expect(address.locator('text=+55')).toBeVisible();
      await expect(address.locator('text=@gmail.com')).toBeVisible();
      await expect(address.locator('text=adarah')).toBeVisible();
    });

    test('minimizes when pressing the arrow button', async ({ page }) => {
      const sidebarControl = page.locator('data-testid=sidebar-control');
      await expect(sidebarControl).toBeVisible();

      sidebarControl.click();

      // Minimizing should hide all images and links
      await expect(sidebar.locator('img')).toBeHidden();
      await expect(sidebar.locator('nav')).toBeHidden();
      await expect(sidebar.locator('address')).toBeHidden();

      // But not the button to expand the sidebar
      await expect(sidebarControl).toBeVisible();
    });
  });
});
