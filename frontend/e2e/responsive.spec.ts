import { test, expect } from '@playwright/test';

test.describe('Responsive Design Tests', () => {
  test.describe('Mobile Viewport Tests', () => {
    test('should display landing page correctly on mobile', async ({ page }) => {
      await page.setViewportSize({ width: 390, height: 844 }); // iPhone 12 Pro
      await page.goto('/');

      // Hero should be visible
      await expect(page.getByText(/write 3x faster/i)).toBeVisible();

      // Header should be visible
      await expect(page.getByText('Talkies', { exact: true })).toBeVisible();

      // CTA buttons should be visible and stacked
      const downloadButton = page.getByRole('button', { name: /download for macOS/i });
      await expect(downloadButton).toBeVisible();
    });

    test('should stack feature cards vertically on mobile', async ({ page }) => {
      await page.setViewportSize({ width: 375, height: 667 });
      await page.goto('/');
      await page.locator('#features').scrollIntoViewIfNeeded();

      // Feature cards should be visible
      await expect(page.getByText('100+ Languages')).toBeVisible();
      await expect(page.getByText('Private & Secure')).toBeVisible();
      await expect(page.getByText('Lightning Fast')).toBeVisible();
    });

    test('should stack pricing cards vertically on mobile', async ({ page }) => {
      await page.setViewportSize({ width: 375, height: 667 });
      await page.goto('/');
      await page.locator('#pricing').scrollIntoViewIfNeeded();

      // Both pricing cards should be visible
      await expect(page.getByText('Free', { exact: true })).toBeVisible();
      await expect(page.getByText('Pro', { exact: true })).toBeVisible();
    });

    test('should display mobile-friendly stat cards', async ({ page }) => {
      await page.setViewportSize({ width: 375, height: 667 });
      await page.goto('/');

      // Stats should be visible and stacked
      await expect(page.getByText('87%')).toBeVisible();
      await expect(page.getByText('500K+')).toBeVisible();
      await expect(page.getByText('100+')).toBeVisible();
      await expect(page.getByText('4.9/5')).toBeVisible();
    });

    test('should make modals responsive on mobile', async ({ page }) => {
      await page.setViewportSize({ width: 375, height: 667 });
      await page.goto('/');

      // Open auth modal
      await page.getByRole('button', { name: /sign in/i }).first().click();

      // Modal should be visible and properly sized
      const modal = page.getByRole('dialog');
      await expect(modal).toBeVisible();

      // Form should be visible
      await expect(page.getByLabel(/email/i)).toBeVisible();
      await expect(page.getByLabel(/password/i)).toBeVisible();
    });

    test('should make dashboard responsive on mobile', async ({ page }) => {
      await page.setViewportSize({ width: 375, height: 667 });
      await page.goto('/dashboard');

      // Header should be visible
      await expect(page.getByText('Talkies Dashboard')).toBeVisible();

      // Stats should stack vertically
      await expect(page.getByText('Total Transcriptions')).toBeVisible();
      await expect(page.getByText('Minutes Used')).toBeVisible();
      await expect(page.getByText('Languages Used')).toBeVisible();
    });
  });

  test.describe('Tablet Viewport Tests', () => {
    test('should display landing page correctly on tablet', async ({ page }) => {
      await page.setViewportSize({ width: 768, height: 1024 }); // iPad
      await page.goto('/');

      // Hero should be visible
      await expect(page.getByText(/write 3x faster/i)).toBeVisible();

      // Navigation should be visible on tablet
      await expect(page.getByRole('link', { name: /features/i })).toBeVisible();
      await expect(page.getByRole('link', { name: /pricing/i })).toBeVisible();
    });

    test('should display feature grid on tablet', async ({ page }) => {
      await page.setViewportSize({ width: 768, height: 1024 });
      await page.goto('/');
      await page.locator('#features').scrollIntoViewIfNeeded();

      // Features should use grid layout
      const featuresGrid = page.locator('#features').locator('.grid');
      await expect(featuresGrid).toBeVisible();
    });

    test('should display dashboard grid on tablet', async ({ page }) => {
      await page.setViewportSize({ width: 768, height: 1024 });
      await page.goto('/dashboard');

      // Stats grid should be visible
      await expect(page.getByText('Total Transcriptions')).toBeVisible();
      await expect(page.getByText('Minutes Used')).toBeVisible();
      await expect(page.getByText('Languages Used')).toBeVisible();
    });
  });

  test.describe('Desktop Viewport Tests', () => {
    test('should display full navigation on desktop', async ({ page }) => {
      await page.setViewportSize({ width: 1920, height: 1080 });
      await page.goto('/');

      // All nav links should be visible
      await expect(page.getByRole('link', { name: /features/i })).toBeVisible();
      await expect(page.getByRole('link', { name: /pricing/i })).toBeVisible();
      await expect(page.getByRole('link', { name: /testimonials/i })).toBeVisible();
      await expect(page.getByRole('link', { name: /faq/i })).toBeVisible();
    });

    test('should display feature cards in grid on desktop', async ({ page }) => {
      await page.setViewportSize({ width: 1920, height: 1080 });
      await page.goto('/');
      await page.locator('#features').scrollIntoViewIfNeeded();

      // All three features should be in a row
      const featuresGrid = page.locator('#features .grid');
      await expect(featuresGrid).toHaveClass(/md:grid-cols-3/);
    });

    test('should display pricing cards side by side on desktop', async ({ page }) => {
      await page.setViewportSize({ width: 1920, height: 1080 });
      await page.goto('/');
      await page.locator('#pricing').scrollIntoViewIfNeeded();

      // Pricing grid should be visible
      const pricingGrid = page.locator('#pricing .grid');
      await expect(pricingGrid).toHaveClass(/md:grid-cols-2/);
    });

    test('should display dashboard stats in row on desktop', async ({ page }) => {
      await page.setViewportSize({ width: 1920, height: 1080 });
      await page.goto('/dashboard');

      // Stats grid should show 3 columns
      const statsGrid = page.locator('.grid.md\\:grid-cols-3').first();
      await expect(statsGrid).toBeVisible();
    });

    test('should center content with max-width on desktop', async ({ page }) => {
      await page.setViewportSize({ width: 1920, height: 1080 });
      await page.goto('/');

      // Check for max-width containers
      const maxWidthContainers = page.locator('.max-w-7xl, .max-w-6xl, .max-w-5xl, .max-w-4xl');
      expect(await maxWidthContainers.count()).toBeGreaterThan(0);
    });
  });

  test.describe('Breakpoint Tests', () => {
    const breakpoints = [
      { name: 'Mobile Small', width: 375, height: 667 },
      { name: 'Mobile Medium', width: 414, height: 896 },
      { name: 'Tablet', width: 768, height: 1024 },
      { name: 'Desktop Small', width: 1280, height: 720 },
      { name: 'Desktop Large', width: 1920, height: 1080 },
    ];

    for (const breakpoint of breakpoints) {
      test(`should render correctly at ${breakpoint.name} (${breakpoint.width}x${breakpoint.height})`, async ({ page }) => {
        await page.setViewportSize({ width: breakpoint.width, height: breakpoint.height });
        await page.goto('/');

        // Page should load without layout issues
        await expect(page.getByText('Talkies', { exact: true })).toBeVisible();
        await expect(page.getByText(/write 3x faster/i)).toBeVisible();

        // No horizontal scrollbar should appear
        const bodyScrollWidth = await page.evaluate(() => document.body.scrollWidth);
        const windowWidth = await page.evaluate(() => window.innerWidth);
        expect(bodyScrollWidth).toBeLessThanOrEqual(windowWidth + 1); // +1 for rounding
      });
    }
  });

  test.describe('Touch Interactions', () => {
    test('should support touch navigation', async ({ page }) => {
      await page.setViewportSize({ width: 390, height: 844 });
      await page.goto('/');

      // Tap on features link
      await page.locator('a[href="#features"]').tap();
      await expect(page.locator('#features')).toBeInViewport();
    });

    test('should open modals on touch', async ({ page }) => {
      await page.setViewportSize({ width: 390, height: 844 });
      await page.goto('/');

      // Tap sign in button
      await page.getByRole('button', { name: /sign in/i }).first().tap();
      await expect(page.getByRole('dialog')).toBeVisible();
    });

    test('should close modals on backdrop tap', async ({ page }) => {
      await page.setViewportSize({ width: 390, height: 844 });
      await page.goto('/');

      // Open and close modal
      await page.getByRole('button', { name: /sign in/i }).first().tap();
      await expect(page.getByRole('dialog')).toBeVisible();

      await page.locator('.backdrop-blur-md').tap();
      await expect(page.getByRole('dialog')).not.toBeVisible();
    });
  });

  test.describe('Orientation Tests', () => {
    test('should handle portrait orientation', async ({ page }) => {
      await page.setViewportSize({ width: 375, height: 812 }); // iPhone X portrait
      await page.goto('/');

      await expect(page.getByText('Talkies', { exact: true })).toBeVisible();
      await expect(page.getByText(/write 3x faster/i)).toBeVisible();
    });

    test('should handle landscape orientation', async ({ page }) => {
      await page.setViewportSize({ width: 812, height: 375 }); // iPhone X landscape
      await page.goto('/');

      await expect(page.getByText('Talkies', { exact: true })).toBeVisible();
      await expect(page.getByText(/write 3x faster/i)).toBeVisible();
    });
  });

  test.describe('Text Scaling', () => {
    test('should handle larger text sizes', async ({ page }) => {
      await page.goto('/');

      // Simulate larger text preference
      await page.addStyleTag({
        content: 'html { font-size: 120%; }',
      });

      // Content should still be readable
      await expect(page.getByText('Talkies', { exact: true })).toBeVisible();
      await expect(page.getByText(/write 3x faster/i)).toBeVisible();
    });
  });

  test.describe('Image and Icon Responsiveness', () => {
    test('should display icons properly on all screen sizes', async ({ page }) => {
      const viewports = [
        { width: 375, height: 667 },
        { width: 1920, height: 1080 },
      ];

      for (const viewport of viewports) {
        await page.setViewportSize(viewport);
        await page.goto('/');

        // Icons should be visible
        const icons = page.locator('svg').first();
        await expect(icons).toBeVisible();
      }
    });
  });
});
