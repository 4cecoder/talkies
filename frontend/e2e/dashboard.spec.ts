import { test, expect } from '@playwright/test';

test.describe('Dashboard Page', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/dashboard');
  });

  test('should load the dashboard page successfully', async ({ page }) => {
    await expect(page.locator('h1, h2').filter({ hasText: /talkies dashboard/i })).toBeVisible();
  });

  test.describe('Header', () => {
    test('should display dashboard header with branding', async ({ page }) => {
      const header = page.locator('header');
      await expect(header).toBeVisible();
      await expect(header.getByText('Talkies Dashboard')).toBeVisible();
    });

    test('should display settings button', async ({ page }) => {
      const settingsButton = page.getByRole('button', { name: /settings/i });
      await expect(settingsButton).toBeVisible();
      await expect(settingsButton).toBeEnabled();
    });

    test('should display user avatar', async ({ page }) => {
      // Check for user icon
      const userAvatar = page.locator('header').locator('.rounded-full').filter({ has: page.locator('svg') });
      await expect(userAvatar).toBeVisible();
    });
  });

  test.describe('Stats Grid', () => {
    test('should display all three stat cards', async ({ page }) => {
      // Total Transcriptions
      await expect(page.getByText('Total Transcriptions')).toBeVisible();
      await expect(page.getByText('1,234')).toBeVisible();
      await expect(page.getByText('+23% this week')).toBeVisible();

      // Minutes Used
      await expect(page.getByText('Minutes Used')).toBeVisible();
      await expect(page.getByText('5,678')).toBeVisible();
      await expect(page.getByText('Unlimited')).toBeVisible();

      // Languages Used
      await expect(page.getByText('Languages Used')).toBeVisible();
      await expect(page.getByText('12', { exact: true })).toBeVisible();
      await expect(page.getByText('100+ available')).toBeVisible();
    });

    test('should display stat icons', async ({ page }) => {
      // Check for TrendingUp, Clock, and Languages icons
      const statCards = page.locator('.group.p-6.rounded-3xl');
      await expect(statCards).toHaveCount(3);

      // Each card should have an icon
      for (let i = 0; i < 3; i++) {
        const card = statCards.nth(i);
        const icon = card.locator('svg').first();
        await expect(icon).toBeVisible();
      }
    });

    test('should have hover effects on stat cards', async ({ page }) => {
      const firstStatCard = page.locator('.group.p-6.rounded-3xl').first();
      await expect(firstStatCard).toHaveClass(/hover:border-purple-500\/50/);
    });
  });

  test.describe('Subscription Card', () => {
    test('should display subscription information', async ({ page }) => {
      await expect(page.getByText('Talkies Pro')).toBeVisible();
      await expect(page.getByText('Your subscription is active')).toBeVisible();
      await expect(page.getByText('Active')).toBeVisible();
    });

    test('should display subscription details', async ({ page }) => {
      // Plan details
      await expect(page.getByText('Plan')).toBeVisible();
      await expect(page.getByText('Pro Monthly')).toBeVisible();

      // Next billing
      await expect(page.getByText('Next Billing')).toBeVisible();
      await expect(page.getByText(/Jan 15, 2025/i)).toBeVisible();

      // Amount
      await expect(page.getByText('Amount')).toBeVisible();
      await expect(page.getByText('$10/month')).toBeVisible();
    });

    test('should display subscription action buttons', async ({ page }) => {
      await expect(page.getByRole('button', { name: /update payment/i })).toBeVisible();
      await expect(page.getByRole('button', { name: /change plan/i })).toBeVisible();
      await expect(page.getByRole('button', { name: /cancel subscription/i })).toBeVisible();
    });

    test('should have gradient border animation', async ({ page }) => {
      const subscriptionCard = page.locator('.mb-12.relative.rounded-3xl').filter({ has: page.getByText('Talkies Pro') });
      const gradientBorder = subscriptionCard.locator('.animate-gradient').first();
      await expect(gradientBorder).toBeVisible();
    });

    test('should display active status badge in green', async ({ page }) => {
      const activeBadge = page.locator('.bg-gradient-to-r.from-green-500.to-emerald-500');
      await expect(activeBadge).toBeVisible();
      await expect(activeBadge).toContainText('Active');
    });
  });

  test.describe('Recent Activity Section', () => {
    test('should display recent transcriptions heading', async ({ page }) => {
      await expect(page.getByText('Recent Transcriptions')).toBeVisible();
    });

    test('should display all transcription items', async ({ page }) => {
      // Check for all four items
      await expect(page.getByText('Team Meeting Notes')).toBeVisible();
      await expect(page.getByText('Product Ideas')).toBeVisible();
      await expect(page.getByText('Interview Recording')).toBeVisible();
      await expect(page.getByText('Lecture Notes')).toBeVisible();
    });

    test('should display transcription metadata', async ({ page }) => {
      // Check first item has all metadata
      const firstItem = page.locator('.space-y-4 > div').first();

      await expect(firstItem.getByText('2 hours ago')).toBeVisible();
      await expect(firstItem.getByText('45 min')).toBeVisible();
      await expect(firstItem.getByText('English')).toBeVisible();
    });

    test('should display different languages in transcriptions', async ({ page }) => {
      await expect(page.getByText('Spanish')).toBeVisible();
      await expect(page.getByText('French')).toBeVisible();
    });

    test('should show chevron icons on transcription items', async ({ page }) => {
      const transcriptionItems = page.locator('.space-y-4 > div');
      const chevronCount = await transcriptionItems.count();

      for (let i = 0; i < chevronCount; i++) {
        const item = transcriptionItems.nth(i);
        const chevron = item.locator('svg').last();
        await expect(chevron).toBeVisible();
      }
    });

    test('should have hover effects on transcription items', async ({ page }) => {
      const firstItem = page.locator('.space-y-4 > div').first();

      // Check hover classes exist
      await expect(firstItem).toHaveClass(/hover:border-purple-500\/50/);
      await expect(firstItem).toHaveClass(/cursor-pointer/);
    });

    test('should display correct time formats', async ({ page }) => {
      await expect(page.getByText('2 hours ago')).toBeVisible();
      await expect(page.getByText('5 hours ago')).toBeVisible();
      await expect(page.getByText('1 day ago')).toBeVisible();
      await expect(page.getByText('2 days ago')).toBeVisible();
    });
  });

  test.describe('Visual Design', () => {
    test('should have dark background', async ({ page }) => {
      const mainDiv = page.locator('div.min-h-screen').first();
      await expect(mainDiv).toHaveClass(/bg-\[#0a0a0f\]/);
    });

    test('should display animated background orbs', async ({ page }) => {
      const glowElements = page.locator('.animate-glow');
      await expect(glowElements.first()).toBeVisible();
      // Should have at least 2 orbs
      expect(await glowElements.count()).toBeGreaterThanOrEqual(2);
    });

    test('should have glassmorphic cards', async ({ page }) => {
      // Check for backdrop blur
      const blurredCards = page.locator('.backdrop-blur-xl');
      expect(await blurredCards.count()).toBeGreaterThan(0);

      // Check for border styling
      const borderedCards = page.locator('.border-white\\/10');
      expect(await borderedCards.count()).toBeGreaterThan(0);
    });

    test('should have gradient text on stats', async ({ page }) => {
      // Check for gradient text classes
      const gradientTexts = page.locator('.bg-gradient-to-r').filter({ has: page.locator('.bg-clip-text') });
      expect(await gradientTexts.count()).toBeGreaterThan(0);
    });
  });

  test.describe('Interactions', () => {
    test('should be able to click settings button', async ({ page }) => {
      const settingsButton = page.getByRole('button', { name: /settings/i });
      await expect(settingsButton).toBeEnabled();
      await settingsButton.click();
      // Button should remain visible after click
      await expect(settingsButton).toBeVisible();
    });

    test('should be able to click Update Payment button', async ({ page }) => {
      const updatePaymentButton = page.getByRole('button', { name: /update payment/i });
      await expect(updatePaymentButton).toBeEnabled();
      await updatePaymentButton.click();
    });

    test('should be able to click Change Plan button', async ({ page }) => {
      const changePlanButton = page.getByRole('button', { name: /change plan/i });
      await expect(changePlanButton).toBeEnabled();
      await changePlanButton.click();
    });

    test('should be able to click Cancel Subscription button', async ({ page }) => {
      const cancelButton = page.getByRole('button', { name: /cancel subscription/i });
      await expect(cancelButton).toBeEnabled();
      await cancelButton.click();
    });

    test('should be able to click transcription items', async ({ page }) => {
      const firstTranscription = page.locator('.space-y-4 > div').first();
      await expect(firstTranscription).toHaveClass(/cursor-pointer/);
      await firstTranscription.click();
    });
  });

  test.describe('Layout and Responsiveness', () => {
    test('should have proper max-width container', async ({ page }) => {
      const mainContent = page.locator('main.max-w-7xl');
      await expect(mainContent).toBeVisible();
    });

    test('should have grid layout for stats', async ({ page }) => {
      const statsGrid = page.locator('.grid.md\\:grid-cols-3').first();
      await expect(statsGrid).toBeVisible();
    });

    test('should have grid layout for subscription details', async ({ page }) => {
      const subscriptionGrid = page.locator('.grid.md\\:grid-cols-3').last();
      await expect(subscriptionGrid).toBeVisible();
    });
  });
});
