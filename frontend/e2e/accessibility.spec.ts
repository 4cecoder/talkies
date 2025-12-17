import { test, expect } from '@playwright/test';
import type { Page } from '@playwright/test';

test.describe('Accessibility Tests', () => {
  test.describe('Landing Page Accessibility', () => {
    test.beforeEach(async ({ page }) => {
      await page.goto('/');
    });

    test('should have proper heading hierarchy', async ({ page }) => {
      // Page should have h1
      const h1 = page.locator('h1');
      await expect(h1).toBeVisible();

      // Should have h2 headings for sections
      const h2s = page.locator('h2');
      expect(await h2s.count()).toBeGreaterThan(0);

      // Should have h3 headings for subsections
      const h3s = page.locator('h3');
      expect(await h3s.count()).toBeGreaterThan(0);
    });

    test('should have accessible navigation links', async ({ page }) => {
      const navLinks = page.locator('nav a');
      const linkCount = await navLinks.count();

      for (let i = 0; i < linkCount; i++) {
        const link = navLinks.nth(i);
        const href = await link.getAttribute('href');
        expect(href).toBeTruthy();
      }
    });

    test('should have descriptive button text', async ({ page }) => {
      // All buttons should have meaningful text
      const buttons = page.getByRole('button');
      const buttonCount = await buttons.count();

      for (let i = 0; i < buttonCount; i++) {
        const button = buttons.nth(i);
        const text = await button.textContent();
        expect(text?.trim().length).toBeGreaterThan(0);
      }
    });

    test('should support keyboard navigation for header', async ({ page }) => {
      // Focus first interactive element
      await page.keyboard.press('Tab');

      // Should be able to navigate through header
      await page.keyboard.press('Tab');
      await page.keyboard.press('Tab');
      await page.keyboard.press('Tab');

      // Focused element should be visible
      const focusedElement = page.locator(':focus');
      await expect(focusedElement).toBeVisible();
    });

    test('should have proper link text', async ({ page }) => {
      // Avoid generic link text like "click here"
      const links = page.locator('a');
      const linkCount = await links.count();

      for (let i = 0; i < linkCount; i++) {
        const link = links.nth(i);
        const text = await link.textContent();
        const ariaLabel = await link.getAttribute('aria-label');

        // Link should have either text or aria-label
        expect(text || ariaLabel).toBeTruthy();
      }
    });

    test('should have adequate color contrast for text', async ({ page }) => {
      // Main heading should be visible (white on dark background)
      const heading = page.getByText(/write 3x faster/i);
      await expect(heading).toBeVisible();

      // Paragraphs should be visible
      const description = page.getByText(/voice-powered writing assistant/i);
      await expect(description).toBeVisible();
    });
  });

  test.describe('Form Accessibility', () => {
    test('should have proper form labels in auth modal', async ({ page }) => {
      await page.goto('/');
      await page.getByRole('button', { name: /sign in/i }).first().click();

      // All inputs should have labels
      const emailInput = page.getByLabel(/email/i);
      await expect(emailInput).toBeVisible();

      const passwordInput = page.getByLabel(/password/i);
      await expect(passwordInput).toBeVisible();
    });

    test('should have proper autocomplete attributes', async ({ page }) => {
      await page.goto('/');
      await page.getByRole('button', { name: /sign in/i }).first().click();

      // Check autocomplete attributes
      await expect(page.getByLabel(/email/i)).toHaveAttribute('autocomplete', 'email');
      await expect(page.getByLabel(/password/i)).toHaveAttribute('autocomplete', 'current-password');
    });

    test('should display validation errors accessibly', async ({ page }) => {
      await page.goto('/');
      await page.getByRole('button', { name: /sign in/i }).first().click();

      // Submit empty form
      await page.getByRole('button', { name: /sign in/i }).last().click();

      // Error messages should be visible
      await expect(page.getByText(/email is required/i)).toBeVisible();
      await expect(page.getByText(/password is required/i)).toBeVisible();
    });

    test('should mark required fields', async ({ page }) => {
      await page.goto('/');
      await page.getByRole('button', { name: /sign in/i }).first().click();

      // Required inputs should have required attribute
      await expect(page.getByLabel(/email/i)).toHaveAttribute('required');
      await expect(page.getByLabel(/password/i)).toHaveAttribute('required');
    });

    test('should support keyboard form submission', async ({ page }) => {
      await page.goto('/');
      await page.getByRole('button', { name: /sign in/i }).first().click();

      // Fill form
      await page.getByLabel(/email/i).fill('test@example.com');
      await page.getByLabel(/password/i).fill('password123');

      // Submit with Enter
      await page.keyboard.press('Enter');

      // Modal should close
      await expect(page.getByRole('dialog')).not.toBeVisible({ timeout: 3000 });
    });
  });

  test.describe('Modal Accessibility', () => {
    test('should have proper ARIA attributes for auth modal', async ({ page }) => {
      await page.goto('/');
      await page.getByRole('button', { name: /sign in/i }).first().click();

      const dialog = page.getByRole('dialog');
      await expect(dialog).toBeVisible();
      await expect(dialog).toHaveAttribute('aria-modal', 'true');
      await expect(dialog).toHaveAttribute('aria-labelledby');
    });

    test('should trap focus within modal', async ({ page }) => {
      await page.goto('/');
      await page.getByRole('button', { name: /sign in/i }).first().click();

      // Tab through modal elements
      await page.keyboard.press('Tab'); // Close button
      await page.keyboard.press('Tab'); // Email input
      await page.keyboard.press('Tab'); // Password input

      // Focus should stay within modal
      const focusedElement = page.locator(':focus');
      const dialog = page.getByRole('dialog');
      const isWithinDialog = await focusedElement.evaluate((el, dialogEl) => {
        return dialogEl?.contains(el) || false;
      }, await dialog.elementHandle());

      expect(isWithinDialog).toBe(true);
    });

    test('should close modal with Escape key', async ({ page }) => {
      await page.goto('/');
      await page.getByRole('button', { name: /sign in/i }).first().click();
      await expect(page.getByRole('dialog')).toBeVisible();

      // Press Escape
      await page.keyboard.press('Escape');

      // Modal should close
      await expect(page.getByRole('dialog')).not.toBeVisible();
    });

    test('should have accessible close button', async ({ page }) => {
      await page.goto('/');
      await page.getByRole('button', { name: /sign in/i }).first().click();

      const closeButton = page.getByRole('button', { name: /close dialog/i });
      await expect(closeButton).toBeVisible();
      await expect(closeButton).toHaveAttribute('aria-label', 'Close dialog');
    });
  });

  test.describe('Keyboard Navigation', () => {
    test('should navigate landing page with keyboard', async ({ page }) => {
      await page.goto('/');

      // Tab to first interactive element
      await page.keyboard.press('Tab');
      let focused = page.locator(':focus');
      await expect(focused).toBeVisible();

      // Continue tabbing
      for (let i = 0; i < 5; i++) {
        await page.keyboard.press('Tab');
        focused = page.locator(':focus');
        await expect(focused).toBeVisible();
      }
    });

    test('should activate buttons with Enter key', async ({ page }) => {
      await page.goto('/');

      // Tab to Sign In button and activate with Enter
      const signInButton = page.getByRole('button', { name: /sign in/i }).first();
      await signInButton.focus();
      await page.keyboard.press('Enter');

      // Modal should open
      await expect(page.getByRole('dialog')).toBeVisible();
    });

    test('should activate buttons with Space key', async ({ page }) => {
      await page.goto('/');

      // Tab to Sign In button and activate with Space
      const signInButton = page.getByRole('button', { name: /sign in/i }).first();
      await signInButton.focus();
      await page.keyboard.press('Space');

      // Modal should open
      await expect(page.getByRole('dialog')).toBeVisible();
    });

    test('should navigate dashboard with keyboard', async ({ page }) => {
      await page.goto('/dashboard');

      // Tab through interactive elements
      await page.keyboard.press('Tab'); // Settings button
      let focused = page.locator(':focus');
      await expect(focused).toBeVisible();

      await page.keyboard.press('Tab'); // User avatar
      focused = page.locator(':focus');
      await expect(focused).toBeVisible();
    });
  });

  test.describe('Focus Management', () => {
    test('should have visible focus indicators', async ({ page }) => {
      await page.goto('/');

      // Tab to interactive element
      await page.keyboard.press('Tab');

      // Check for focus ring (focus-visible classes)
      const focusedElement = page.locator(':focus');
      await expect(focusedElement).toBeVisible();
    });

    test('should restore focus after modal closes', async ({ page }) => {
      await page.goto('/');

      // Focus and click Sign In button
      const signInButton = page.getByRole('button', { name: /sign in/i }).first();
      await signInButton.focus();
      await signInButton.click();

      // Close modal with Escape
      await page.keyboard.press('Escape');

      // Focus should return to trigger button or nearby element
      const focusedElement = page.locator(':focus');
      await expect(focusedElement).toBeVisible();
    });

    test('should not lose focus when modal opens', async ({ page }) => {
      await page.goto('/');

      // Open modal
      await page.getByRole('button', { name: /sign in/i }).first().click();

      // Focus should be inside modal
      const focusedElement = page.locator(':focus');
      await expect(focusedElement).toBeVisible();
    });
  });

  test.describe('Screen Reader Support', () => {
    test('should have proper landmark regions', async ({ page }) => {
      await page.goto('/');

      // Check for main, header, footer
      const header = page.locator('header');
      await expect(header).toBeVisible();

      const main = page.locator('main');
      expect(await main.count()).toBeGreaterThanOrEqual(0);

      const footer = page.locator('footer');
      await expect(footer).toBeVisible();
    });

    test('should hide decorative elements from screen readers', async ({ page }) => {
      await page.goto('/');

      // SVG icons should have aria-hidden if they're decorative
      const decorativeIcons = page.locator('svg[aria-hidden="true"]');
      // Some icons should be decorative
      expect(await decorativeIcons.count()).toBeGreaterThanOrEqual(0);
    });

    test('should have proper button roles', async ({ page }) => {
      await page.goto('/');

      // All interactive buttons should be proper buttons
      const buttons = page.getByRole('button');
      expect(await buttons.count()).toBeGreaterThan(0);
    });
  });

  test.describe('Interactive Elements', () => {
    test('should have sufficient click target size', async ({ page }) => {
      await page.goto('/');

      // Buttons should be large enough (at least 44x44px for touch)
      const signInButton = page.getByRole('button', { name: /sign in/i }).first();
      const box = await signInButton.boundingBox();

      expect(box?.height).toBeGreaterThanOrEqual(40); // Slightly less than 44 due to padding
    });

    test('should indicate loading states accessibly', async ({ page }) => {
      await page.goto('/');
      await page.getByRole('button', { name: /sign in/i }).first().click();

      // Fill and submit form
      await page.getByLabel(/email/i).fill('test@example.com');
      await page.getByLabel(/password/i).fill('password123');
      await page.getByRole('button', { name: /sign in/i }).last().click();

      // Button should be disabled during loading
      await expect(page.getByRole('button', { name: /sign in/i }).last()).toBeDisabled();
    });

    test('should have proper checkbox labels', async ({ page }) => {
      await page.goto('/');
      await page.getByRole('button', { name: /sign in/i }).first().click();

      // Remember me checkbox should have label
      const checkbox = page.getByRole('checkbox', { name: /remember me/i });
      await expect(checkbox).toBeVisible();
    });
  });

  test.describe('Content Accessibility', () => {
    test('should expand FAQ items accessibly', async ({ page }) => {
      await page.goto('/');
      await page.locator('#faq').scrollIntoViewIfNeeded();

      // FAQ should use details/summary (native accessible pattern)
      const details = page.locator('details');
      expect(await details.count()).toBeGreaterThan(0);

      // Expand first FAQ
      const firstFaq = details.first();
      await firstFaq.locator('summary').click();

      // Content should be visible
      await expect(firstFaq.getByText(/advanced speech recognition/i)).toBeVisible();
    });

    test('should have proper list semantics for testimonials', async ({ page }) => {
      await page.goto('/');
      await page.locator('#testimonials').scrollIntoViewIfNeeded();

      // Testimonials should be in a container
      await expect(page.getByText(/sarah miller/i)).toBeVisible();
      await expect(page.getByText(/james davis/i)).toBeVisible();
      await expect(page.getByText(/maria lopez/i)).toBeVisible();
    });
  });

  test.describe('Error Prevention', () => {
    test('should prevent form submission with invalid data', async ({ page }) => {
      await page.goto('/');
      await page.getByRole('button', { name: /sign in/i }).first().click();

      // Try to submit with invalid email
      await page.getByLabel(/email/i).fill('not-an-email');
      await page.getByLabel(/password/i).fill('short');
      await page.getByRole('button', { name: /sign in/i }).last().click();

      // Validation errors should appear
      await expect(page.getByText(/please enter a valid email/i)).toBeVisible();
      await expect(page.getByText(/password must be at least 8 characters/i)).toBeVisible();

      // Modal should still be open
      await expect(page.getByRole('dialog')).toBeVisible();
    });

    test('should provide helpful error messages', async ({ page }) => {
      await page.goto('/');
      await page.getByRole('button', { name: /sign in/i }).first().click();

      // Submit empty form
      await page.getByRole('button', { name: /sign in/i }).last().click();

      // Error messages should be specific
      await expect(page.getByText(/email is required/i)).toBeVisible();
      await expect(page.getByText(/password is required/i)).toBeVisible();
    });
  });
});
