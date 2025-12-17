import { test, expect } from '@playwright/test';

test.describe('Auth Modal', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('should open auth modal when clicking Sign In button', async ({ page }) => {
    // Click Sign In button
    await page.getByRole('button', { name: /sign in/i }).first().click();

    // Check modal is visible
    await expect(page.getByRole('dialog')).toBeVisible();
    await expect(page.getByText('Welcome Back')).toBeVisible();
    await expect(page.getByText('Sign in to your account')).toBeVisible();
  });

  test('should open auth modal in signup mode when clicking signup CTA', async ({ page }) => {
    // Click a signup button
    await page.getByRole('button', { name: /download free/i }).first().click();

    // Check modal is visible with signup mode
    await expect(page.getByRole('dialog')).toBeVisible();
    await expect(page.getByText('Get Started')).toBeVisible();
    await expect(page.getByText('Create your account')).toBeVisible();
  });

  test('should close modal when clicking X button', async ({ page }) => {
    // Open modal
    await page.getByRole('button', { name: /sign in/i }).first().click();
    await expect(page.getByRole('dialog')).toBeVisible();

    // Close modal
    await page.getByRole('button', { name: /close dialog/i }).click();
    await expect(page.getByRole('dialog')).not.toBeVisible();
  });

  test('should close modal when clicking backdrop', async ({ page }) => {
    // Open modal
    await page.getByRole('button', { name: /sign in/i }).first().click();
    await expect(page.getByRole('dialog')).toBeVisible();

    // Click backdrop (the blurred background)
    await page.locator('.backdrop-blur-md').click();
    await expect(page.getByRole('dialog')).not.toBeVisible();
  });

  test.describe('Login Form', () => {
    test.beforeEach(async ({ page }) => {
      await page.goto('/');
      await page.getByRole('button', { name: /sign in/i }).first().click();
      await expect(page.getByRole('dialog')).toBeVisible();
    });

    test('should display login form fields', async ({ page }) => {
      // Check form fields
      await expect(page.getByLabel(/email/i)).toBeVisible();
      await expect(page.getByLabel(/password/i)).toBeVisible();
      await expect(page.getByText(/remember me/i)).toBeVisible();
      await expect(page.getByText(/forgot password/i)).toBeVisible();
      await expect(page.getByRole('button', { name: /sign in/i }).last()).toBeVisible();
    });

    test('should validate email field', async ({ page }) => {
      // Submit without email
      await page.getByRole('button', { name: /sign in/i }).last().click();
      await expect(page.getByText(/email is required/i)).toBeVisible();

      // Enter invalid email
      await page.getByLabel(/email/i).fill('invalid-email');
      await page.getByRole('button', { name: /sign in/i }).last().click();
      await expect(page.getByText(/please enter a valid email/i)).toBeVisible();
    });

    test('should validate password field', async ({ page }) => {
      // Submit without password
      await page.getByLabel(/email/i).fill('test@example.com');
      await page.getByRole('button', { name: /sign in/i }).last().click();
      await expect(page.getByText(/password is required/i)).toBeVisible();

      // Enter short password
      await page.getByLabel(/password/i).fill('short');
      await page.getByRole('button', { name: /sign in/i }).last().click();
      await expect(page.getByText(/password must be at least 8 characters/i)).toBeVisible();
    });

    test('should submit valid login form', async ({ page }) => {
      // Fill form
      await page.getByLabel(/email/i).fill('test@example.com');
      await page.getByLabel(/password/i).fill('password123');

      // Submit
      await page.getByRole('button', { name: /sign in/i }).last().click();

      // Check loading state
      await expect(page.getByRole('button', { name: /sign in/i }).last()).toBeDisabled();

      // Modal should close after submission
      await expect(page.getByRole('dialog')).not.toBeVisible({ timeout: 3000 });
    });

    test('should toggle remember me checkbox', async ({ page }) => {
      const checkbox = page.getByRole('checkbox', { name: /remember me/i });

      // Check initial state
      await expect(checkbox).not.toBeChecked();

      // Toggle on
      await checkbox.check();
      await expect(checkbox).toBeChecked();

      // Toggle off
      await checkbox.uncheck();
      await expect(checkbox).not.toBeChecked();
    });

    test('should display social login buttons', async ({ page }) => {
      await expect(page.getByRole('button', { name: /sign in with google/i })).toBeVisible();
      await expect(page.getByRole('button', { name: /sign in with github/i })).toBeVisible();
    });

    test('should switch to signup mode', async ({ page }) => {
      // Click signup link
      await page.getByRole('button', { name: /sign up/i }).click();

      // Check mode switched
      await expect(page.getByText('Get Started')).toBeVisible();
      await expect(page.getByText('Create your account')).toBeVisible();
      await expect(page.getByLabel(/name/i)).toBeVisible();
    });
  });

  test.describe('Signup Form', () => {
    test.beforeEach(async ({ page }) => {
      await page.goto('/');
      await page.getByRole('button', { name: /download free/i }).first().click();
      await expect(page.getByRole('dialog')).toBeVisible();
    });

    test('should display signup form fields', async ({ page }) => {
      // Check form fields
      await expect(page.getByLabel(/name/i)).toBeVisible();
      await expect(page.getByLabel(/email/i)).toBeVisible();
      await expect(page.getByLabel(/password/i)).toBeVisible();
      await expect(page.getByText(/must be at least 8 characters/i)).toBeVisible();
      await expect(page.getByRole('button', { name: /create account/i })).toBeVisible();
    });

    test('should validate name field', async ({ page }) => {
      // Submit without name
      await page.getByRole('button', { name: /create account/i }).click();
      await expect(page.getByText(/name is required/i)).toBeVisible();
    });

    test('should validate email field', async ({ page }) => {
      // Submit without email
      await page.getByLabel(/name/i).fill('Test User');
      await page.getByRole('button', { name: /create account/i }).click();
      await expect(page.getByText(/email is required/i)).toBeVisible();

      // Enter invalid email
      await page.getByLabel(/email/i).fill('not-an-email');
      await page.getByRole('button', { name: /create account/i }).click();
      await expect(page.getByText(/please enter a valid email/i)).toBeVisible();
    });

    test('should validate password field', async ({ page }) => {
      // Fill name and email
      await page.getByLabel(/name/i).fill('Test User');
      await page.getByLabel(/email/i).fill('test@example.com');

      // Submit without password
      await page.getByRole('button', { name: /create account/i }).click();
      await expect(page.getByText(/password is required/i)).toBeVisible();

      // Enter short password
      await page.getByLabel(/password/i).fill('short');
      await page.getByRole('button', { name: /create account/i }).click();
      await expect(page.getByText(/password must be at least 8 characters/i)).toBeVisible();
    });

    test('should submit valid signup form', async ({ page }) => {
      // Fill form
      await page.getByLabel(/name/i).fill('Test User');
      await page.getByLabel(/email/i).fill('test@example.com');
      await page.getByLabel(/password/i).fill('password123');

      // Submit
      await page.getByRole('button', { name: /create account/i }).click();

      // Check loading state
      await expect(page.getByRole('button', { name: /create account/i })).toBeDisabled();

      // Modal should close after submission
      await expect(page.getByRole('dialog')).not.toBeVisible({ timeout: 3000 });
    });

    test('should switch to login mode', async ({ page }) => {
      // Click sign in link
      await page.getByRole('button', { name: /sign in/i }).last().click();

      // Check mode switched
      await expect(page.getByText('Welcome Back')).toBeVisible();
      await expect(page.getByText('Sign in to your account')).toBeVisible();
      await expect(page.getByLabel(/name/i)).not.toBeVisible();
    });

    test('should display social signup buttons', async ({ page }) => {
      await expect(page.getByRole('button', { name: /sign in with google/i })).toBeVisible();
      await expect(page.getByRole('button', { name: /sign in with github/i })).toBeVisible();
    });
  });

  test.describe('Form Accessibility', () => {
    test('should have proper ARIA labels', async ({ page }) => {
      await page.getByRole('button', { name: /sign in/i }).first().click();

      const dialog = page.getByRole('dialog');
      await expect(dialog).toHaveAttribute('aria-modal', 'true');
      await expect(dialog).toHaveAttribute('aria-labelledby', 'auth-modal-title');
    });

    test('should support keyboard navigation', async ({ page }) => {
      await page.getByRole('button', { name: /sign in/i }).first().click();

      // Tab through form elements
      await page.keyboard.press('Tab'); // Close button
      await page.keyboard.press('Tab'); // Email field
      await page.keyboard.press('Tab'); // Password field
      await page.keyboard.press('Tab'); // Remember me checkbox

      // Submit with Enter key
      await page.getByLabel(/email/i).fill('test@example.com');
      await page.getByLabel(/password/i).fill('password123');
      await page.keyboard.press('Enter');

      // Modal should close
      await expect(page.getByRole('dialog')).not.toBeVisible({ timeout: 3000 });
    });

    test('should have proper focus management', async ({ page }) => {
      await page.getByRole('button', { name: /sign in/i }).first().click();

      // Close button should be focusable
      const closeButton = page.getByRole('button', { name: /close dialog/i });
      await expect(closeButton).toHaveAttribute('aria-label', 'Close dialog');

      // Form inputs should have proper autocomplete
      await expect(page.getByLabel(/email/i)).toHaveAttribute('autocomplete', 'email');
      await expect(page.getByLabel(/password/i)).toHaveAttribute('autocomplete', 'current-password');
    });
  });
});
