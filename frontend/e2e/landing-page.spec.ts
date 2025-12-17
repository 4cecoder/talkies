import { test, expect } from '@playwright/test';

test.describe('Landing Page', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('should load the landing page successfully', async ({ page }) => {
    await expect(page).toHaveTitle(/Talkies/i);
    await expect(page.locator('h1')).toBeVisible();
  });

  test('should display the header with navigation', async ({ page }) => {
    // Check header is visible
    const header = page.locator('header');
    await expect(header).toBeVisible();

    // Check logo/brand
    await expect(page.getByText('Talkies', { exact: true })).toBeVisible();

    // Check navigation links (desktop)
    await expect(page.getByRole('link', { name: /features/i })).toBeVisible();
    await expect(page.getByRole('link', { name: /pricing/i })).toBeVisible();
    await expect(page.getByRole('link', { name: /testimonials/i })).toBeVisible();
    await expect(page.getByRole('link', { name: /faq/i })).toBeVisible();

    // Check auth buttons
    await expect(page.getByRole('button', { name: /sign in/i })).toBeVisible();
    await expect(page.getByRole('button', { name: /get started/i })).toBeVisible();
  });

  test('should display hero section with correct content', async ({ page }) => {
    // Check hero heading
    await expect(page.getByText(/write 3x faster/i)).toBeVisible();
    await expect(page.getByText(/without lifting a finger/i)).toBeVisible();

    // Check description
    await expect(page.getByText(/voice-powered writing assistant/i)).toBeVisible();

    // Check CTA button
    await expect(page.getByRole('button', { name: /download for macOS/i })).toBeVisible();

    // Check requirements badge
    await expect(page.getByText(/requires macOS 15\+/i)).toBeVisible();
  });

  test('should display all feature cards', async ({ page }) => {
    const featuresSection = page.locator('#features');
    await featuresSection.scrollIntoViewIfNeeded();

    // Check section heading
    await expect(featuresSection.getByText(/powerful features/i)).toBeVisible();

    // Check all three feature cards
    await expect(page.getByText('100+ Languages')).toBeVisible();
    await expect(page.getByText(/speak in any language/i)).toBeVisible();

    await expect(page.getByText('Private & Secure')).toBeVisible();
    await expect(page.getByText(/everything stays on your device/i)).toBeVisible();

    await expect(page.getByText('Lightning Fast')).toBeVisible();
    await expect(page.getByText(/no wifi required/i)).toBeVisible();
  });

  test('should display social proof stats', async ({ page }) => {
    // Check all four stat cards
    await expect(page.getByText('87%')).toBeVisible();
    await expect(page.getByText('Faster Writing')).toBeVisible();

    await expect(page.getByText('500K+')).toBeVisible();
    await expect(page.getByText('Active Users')).toBeVisible();

    await expect(page.getByText('100+')).toBeVisible();
    await expect(page.getByText('Languages')).toBeVisible();

    await expect(page.getByText('4.9/5')).toBeVisible();
    await expect(page.getByText('User Rating')).toBeVisible();
  });

  test('should display testimonials section', async ({ page }) => {
    const testimonialsSection = page.locator('#testimonials');
    await testimonialsSection.scrollIntoViewIfNeeded();

    // Check section heading
    await expect(testimonialsSection.getByText(/loved by creators worldwide/i)).toBeVisible();

    // Check testimonials
    await expect(page.getByText(/sarah miller/i)).toBeVisible();
    await expect(page.getByText(/tech journalist/i)).toBeVisible();

    await expect(page.getByText(/james davis/i)).toBeVisible();
    await expect(page.getByText(/product manager/i)).toBeVisible();

    await expect(page.getByText(/maria lopez/i)).toBeVisible();
    await expect(page.getByText(/content creator/i)).toBeVisible();

    // Check star ratings are visible
    const stars = page.locator('svg').filter({ has: page.locator('.fill-yellow-400') });
    await expect(stars.first()).toBeVisible();
  });

  test('should display pricing section with both plans', async ({ page }) => {
    const pricingSection = page.locator('#pricing');
    await pricingSection.scrollIntoViewIfNeeded();

    // Check section heading
    await expect(pricingSection.getByText(/simple pricing/i)).toBeVisible();

    // Check Free plan
    await expect(page.getByText('Free', { exact: true })).toBeVisible();
    await expect(page.getByText('$0', { exact: true })).toBeVisible();
    await expect(page.getByText(/basic voice transcription/i)).toBeVisible();
    await expect(page.getByText(/10 minutes per day/i)).toBeVisible();

    // Check Pro plan
    await expect(page.getByText('Pro', { exact: true })).toBeVisible();
    await expect(page.getByText('$10')).toBeVisible();
    await expect(page.getByText(/unlimited transcription/i)).toBeVisible();
    await expect(page.getByText('Popular')).toBeVisible();

    // Check CTA buttons
    await expect(page.getByRole('button', { name: /download free/i })).toBeVisible();
    await expect(page.getByRole('button', { name: /get pro/i })).toBeVisible();
  });

  test('should display FAQ section', async ({ page }) => {
    const faqSection = page.locator('#faq');
    await faqSection.scrollIntoViewIfNeeded();

    // Check section heading
    await expect(faqSection.getByText(/frequently asked questions/i)).toBeVisible();

    // Check FAQ items
    await expect(page.getByText(/how does the voice transcription work/i)).toBeVisible();
    await expect(page.getByText(/is my data secure/i)).toBeVisible();
    await expect(page.getByText(/can i use it offline/i)).toBeVisible();
  });

  test('should expand FAQ items when clicked', async ({ page }) => {
    const faqSection = page.locator('#faq');
    await faqSection.scrollIntoViewIfNeeded();

    // Click first FAQ
    const firstFaq = page.locator('details').first();
    await firstFaq.locator('summary').click();

    // Check that content is visible
    await expect(firstFaq.getByText(/advanced speech recognition/i)).toBeVisible();

    // Click to collapse
    await firstFaq.locator('summary').click();
  });

  test('should display final CTA section', async ({ page }) => {
    await page.locator('text=Ready to write faster?').scrollIntoViewIfNeeded();

    // Check heading
    await expect(page.getByText(/ready to write faster/i)).toBeVisible();

    // Check description
    await expect(page.getByText(/join 500,000\+ users/i)).toBeVisible();

    // Check CTA buttons
    await expect(page.getByRole('button', { name: /start free trial/i })).toBeVisible();
    await expect(page.getByRole('button', { name: /try free version/i })).toBeVisible();

    // Check trust badges
    await expect(page.getByText(/no credit card required/i)).toBeVisible();
    await expect(page.getByText(/cancel anytime/i)).toBeVisible();
    await expect(page.getByText(/14-day money back/i)).toBeVisible();
  });

  test('should display footer', async ({ page }) => {
    const footer = page.locator('footer');
    await footer.scrollIntoViewIfNeeded();

    // Check copyright
    await expect(footer.getByText(/© 2025/i)).toBeVisible();
    await expect(footer.getByText('Talkies')).toBeVisible();

    // Check footer links
    await expect(footer.getByRole('link', { name: /privacy/i })).toBeVisible();
    await expect(footer.getByRole('link', { name: /terms/i })).toBeVisible();
    await expect(footer.getByRole('link', { name: /contact/i })).toBeVisible();
  });

  test('should navigate to sections when clicking nav links', async ({ page }) => {
    // Click Features link
    await page.getByRole('link', { name: /features/i }).click();
    await expect(page.locator('#features')).toBeInViewport();

    // Click Pricing link
    await page.getByRole('link', { name: /pricing/i }).click();
    await expect(page.locator('#pricing')).toBeInViewport();

    // Click Testimonials link
    await page.getByRole('link', { name: /testimonials/i }).click();
    await expect(page.locator('#testimonials')).toBeInViewport();

    // Click FAQ link
    await page.getByRole('link', { name: /faq/i }).click();
    await expect(page.locator('#faq')).toBeInViewport();
  });

  test('should have proper gradient animations', async ({ page }) => {
    // Check for animated gradient classes
    const gradientElements = page.locator('.animate-gradient');
    await expect(gradientElements.first()).toBeVisible();

    const glowElements = page.locator('.animate-glow');
    await expect(glowElements.first()).toBeVisible();
  });
});
