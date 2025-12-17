import { test, expect } from '@playwright/test';

test.describe('Checkout Modal', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('should open checkout modal when clicking Get Started button', async ({ page }) => {
    // Click Get Started button in header
    await page.getByRole('button', { name: /get started/i }).first().click();

    // Check modal is visible
    const modal = page.locator('.fixed.inset-0.z-50').filter({ has: page.getByText('Complete Your Purchase') });
    await expect(modal).toBeVisible();
  });

  test('should open checkout modal from pricing section', async ({ page }) => {
    // Scroll to pricing section
    await page.locator('#pricing').scrollIntoViewIfNeeded();

    // Click Get Pro button
    await page.getByRole('button', { name: /get pro/i }).click();

    // Check modal is visible
    await expect(page.getByText('Complete Your Purchase')).toBeVisible();
    await expect(page.getByText('Start your Talkies Pro subscription today')).toBeVisible();
  });

  test('should close modal when clicking X button', async ({ page }) => {
    // Open modal
    await page.getByRole('button', { name: /get started/i }).first().click();
    await expect(page.getByText('Complete Your Purchase')).toBeVisible();

    // Click close button
    const closeButton = page.locator('button').filter({ has: page.locator('svg').first() }).first();
    await closeButton.click();

    // Modal should close
    await expect(page.getByText('Complete Your Purchase')).not.toBeVisible();
  });

  test('should close modal when clicking backdrop', async ({ page }) => {
    // Open modal
    await page.getByRole('button', { name: /get started/i }).first().click();
    await expect(page.getByText('Complete Your Purchase')).toBeVisible();

    // Click backdrop
    await page.locator('.fixed.inset-0.bg-black\\/60').click();

    // Modal should close
    await expect(page.getByText('Complete Your Purchase')).not.toBeVisible();
  });

  test.describe('Billing Cycle Toggle', () => {
    test.beforeEach(async ({ page }) => {
      await page.goto('/');
      await page.getByRole('button', { name: /get started/i }).first().click();
      await expect(page.getByText('Complete Your Purchase')).toBeVisible();
    });

    test('should display monthly billing by default', async ({ page }) => {
      // Check Monthly button is active
      const monthlyButton = page.getByRole('button', { name: /^monthly$/i });
      await expect(monthlyButton).toHaveClass(/from-purple-600/);

      // Check price display
      await expect(page.getByText('$10')).toBeVisible();
      await expect(page.getByText('/mo')).toBeVisible();
    });

    test('should switch to yearly billing', async ({ page }) => {
      // Click Yearly button
      const yearlyButton = page.getByRole('button', { name: /yearly/i });
      await yearlyButton.click();

      // Check Yearly button is active
      await expect(yearlyButton).toHaveClass(/from-purple-600/);

      // Check Save 20% badge is visible
      await expect(page.getByText('Save 20%')).toBeVisible();

      // Check price updated to annual
      await expect(page.getByText('$96')).toBeVisible();
      await expect(page.getByText('/yr')).toBeVisible();
    });

    test('should switch back to monthly billing', async ({ page }) => {
      // Switch to yearly
      await page.getByRole('button', { name: /yearly/i }).click();
      await expect(page.getByText('$96')).toBeVisible();

      // Switch back to monthly
      const monthlyButton = page.getByRole('button', { name: /^monthly$/i });
      await monthlyButton.click();

      // Check Monthly button is active
      await expect(monthlyButton).toHaveClass(/from-purple-600/);

      // Check price is monthly again
      await expect(page.getByText('$10')).toBeVisible();
      await expect(page.getByText('/mo')).toBeVisible();
    });
  });

  test.describe('Order Summary', () => {
    test.beforeEach(async ({ page }) => {
      await page.goto('/');
      await page.getByRole('button', { name: /get started/i }).first().click();
      await expect(page.getByText('Complete Your Purchase')).toBeVisible();
    });

    test('should display monthly order summary correctly', async ({ page }) => {
      // Check order summary section
      await expect(page.getByText('Order Summary')).toBeVisible();
      await expect(page.getByText('Talkies Pro (Monthly)')).toBeVisible();
      await expect(page.getByText('$10/mo')).toBeVisible();
      await expect(page.getByText('Total')).toBeVisible();
    });

    test('should display yearly order summary with discount', async ({ page }) => {
      // Switch to yearly
      await page.getByRole('button', { name: /yearly/i }).click();

      // Check order summary
      await expect(page.getByText('Talkies Pro (Annual)')).toBeVisible();
      await expect(page.getByText('$96/yr')).toBeVisible();
      await expect(page.getByText('Annual discount (20%)')).toBeVisible();
      await expect(page.getByText('-$24')).toBeVisible();
    });

    test('should update total when switching billing cycles', async ({ page }) => {
      // Check monthly total
      const totalSection = page.locator('text=Total').locator('..');
      await expect(totalSection.getByText('$10/mo')).toBeVisible();

      // Switch to yearly
      await page.getByRole('button', { name: /yearly/i }).click();

      // Check yearly total
      await expect(totalSection.getByText('$96/yr')).toBeVisible();
    });
  });

  test.describe('Checkout Button', () => {
    test.beforeEach(async ({ page }) => {
      await page.goto('/');
      await page.getByRole('button', { name: /get started/i }).first().click();
      await expect(page.getByText('Complete Your Purchase')).toBeVisible();
    });

    test('should display checkout button with correct text', async ({ page }) => {
      const checkoutButton = page.getByRole('button', { name: /continue to checkout/i });
      await expect(checkoutButton).toBeVisible();
      await expect(checkoutButton).toBeEnabled();
    });

    test('should show loading state when checkout is initiated', async ({ page }) => {
      // Note: This test will fail because the API doesn't exist yet
      // We're testing the UI behavior only

      const checkoutButton = page.getByRole('button', { name: /continue to checkout/i });

      // Click checkout button
      await checkoutButton.click();

      // Should show loading state
      await expect(page.getByText(/redirecting to stripe/i)).toBeVisible({ timeout: 1000 });
      await expect(checkoutButton).toBeDisabled();
    });

    test('should display security badges', async ({ page }) => {
      await expect(page.getByText(/secured by stripe/i)).toBeVisible();
      await expect(page.getByText('Cancel anytime')).toBeVisible();
      await expect(page.getByText('Money-back guarantee')).toBeVisible();
    });
  });

  test.describe('Trust Elements', () => {
    test.beforeEach(async ({ page }) => {
      await page.goto('/');
      await page.getByRole('button', { name: /get started/i }).first().click();
      await expect(page.getByText('Complete Your Purchase')).toBeVisible();
    });

    test('should display trust badges at bottom', async ({ page }) => {
      await expect(page.getByText('Secure Payment')).toBeVisible();
      await expect(page.getByText('Money-back Guarantee')).toBeVisible();
      await expect(page.getByText('Cancel Anytime')).toBeVisible();
    });

    test('should display security icons', async ({ page }) => {
      // Check for shield icon (secure payment)
      const shieldIcon = page.locator('svg').filter({ hasText: '' }).first();
      await expect(shieldIcon).toBeVisible();

      // Check for lock icon in button
      const lockIcon = page.locator('button:has-text("Continue to Checkout")').locator('svg').first();
      await expect(lockIcon).toBeVisible();
    });
  });

  test.describe('Visual Design', () => {
    test.beforeEach(async ({ page }) => {
      await page.goto('/');
      await page.getByRole('button', { name: /get started/i }).first().click();
      await expect(page.getByText('Complete Your Purchase')).toBeVisible();
    });

    test('should have gradient border animation', async ({ page }) => {
      // Check for animated gradient border
      const gradientBorder = page.locator('.animate-gradient').first();
      await expect(gradientBorder).toBeVisible();
    });

    test('should display Popular badge on yearly option', async ({ page }) => {
      const yearlyButton = page.getByRole('button', { name: /yearly/i });
      await expect(yearlyButton.locator('text=Save 20%')).toBeVisible();
    });

    test('should have proper glassmorphic styling', async ({ page }) => {
      // Check for backdrop blur
      const modal = page.locator('.backdrop-blur-xl').first();
      await expect(modal).toBeVisible();

      // Check for border styling
      const borderElement = page.locator('.border-white\\/10').first();
      await expect(borderElement).toBeVisible();
    });
  });

  test.describe('Error Handling', () => {
    test('should display error message when checkout fails', async ({ page }) => {
      // Open modal
      await page.getByRole('button', { name: /get started/i }).first().click();
      await expect(page.getByText('Complete Your Purchase')).toBeVisible();

      // Mock API to return error by intercepting the request
      await page.route('**/api/create-checkout-session', (route) => {
        route.fulfill({
          status: 400,
          contentType: 'application/json',
          body: JSON.stringify({ error: 'Failed to create checkout session' }),
        });
      });

      // Click checkout button
      await page.getByRole('button', { name: /continue to checkout/i }).click();

      // Should display error message
      await expect(page.getByText(/failed to create checkout session/i)).toBeVisible({ timeout: 3000 });

      // Button should be enabled again
      await expect(page.getByRole('button', { name: /continue to checkout/i })).toBeEnabled();
    });
  });
});
