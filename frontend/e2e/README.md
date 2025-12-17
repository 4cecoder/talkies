# End-to-End Testing with Playwright

This directory contains E2E tests for the Talkies frontend using Playwright.

## Test Structure

- `landing-page.spec.ts` - Tests for the main landing page (hero, features, pricing, testimonials, FAQ)
- `auth-modal.spec.ts` - Tests for authentication modal (login/signup flows, validation)
- `checkout-modal.spec.ts` - Tests for checkout modal (billing cycles, payment flow)
- `dashboard.spec.ts` - Tests for dashboard page (stats, subscription, activity)
- `responsive.spec.ts` - Responsive design tests (mobile, tablet, desktop viewports)
- `accessibility.spec.ts` - Accessibility tests (WCAG compliance, keyboard navigation, screen readers)

## Running Tests

### Run all tests (headless mode)
```bash
npm run test:e2e
```

### Run tests with UI mode (interactive)
```bash
npm run test:e2e:ui
```

### Run tests in debug mode
```bash
npm run test:e2e:debug
```

### Run tests in headed mode (see browser)
```bash
npm run test:e2e:headed
```

### Run specific browser tests
```bash
npm run test:e2e:chromium
```

### View test report
```bash
npm run test:e2e:report
```

### Run specific test file
```bash
npx playwright test e2e/landing-page.spec.ts
```

### Run specific test by name
```bash
npx playwright test -g "should display landing page correctly"
```

## Test Coverage

### Landing Page Tests
- Page load and basic rendering
- Header navigation and branding
- Hero section with CTAs
- Features section (3 feature cards)
- Social proof stats (4 stat cards)
- Testimonials section (3 testimonials)
- Pricing section (Free and Pro plans)
- FAQ section with expandable items
- Final CTA section
- Footer with links
- Smooth scrolling navigation
- Gradient animations

### Auth Modal Tests
- Modal open/close functionality
- Login form validation
  - Email validation (required, format)
  - Password validation (required, min length)
  - Remember me checkbox
  - Social login buttons
- Signup form validation
  - Name validation
  - Email validation
  - Password validation
  - Social signup buttons
- Mode switching (login ↔ signup)
- Form submission with loading states
- Accessibility (ARIA attributes, keyboard navigation)

### Checkout Modal Tests
- Modal open/close functionality
- Billing cycle toggle (monthly/yearly)
- Order summary display
- Discount calculations
- Checkout button with loading states
- Error handling for failed checkouts
- Trust badges and security indicators
- Visual design (gradient borders, glassmorphism)

### Dashboard Tests
- Header with settings and user avatar
- Stats grid (3 stat cards)
  - Total Transcriptions
  - Minutes Used
  - Languages Used
- Subscription card
  - Active status badge
  - Plan details (plan, billing, amount)
  - Action buttons (Update Payment, Change Plan, Cancel)
- Recent transcriptions list
  - 4 recent items with metadata
  - Hover effects and click interactions
- Visual design elements

### Responsive Design Tests
- Mobile viewport (iPhone 12)
  - Proper layout stacking
  - Touch interactions
  - Mobile-friendly navigation
- Tablet viewport (iPad)
  - Grid layouts
  - Navigation visibility
- Desktop viewport (1920x1080)
  - Full navigation display
  - Multi-column grids
  - Centered content with max-width
- Breakpoint tests (375px to 1920px)
- Orientation tests (portrait/landscape)
- Text scaling support

### Accessibility Tests
- Heading hierarchy (h1, h2, h3)
- Keyboard navigation
  - Tab order
  - Enter/Space key activation
  - Escape key for modals
- Focus management
  - Visible focus indicators
  - Focus trap in modals
  - Focus restoration after modal close
- Form accessibility
  - Proper labels
  - Required field indicators
  - Autocomplete attributes
  - Error message visibility
- ARIA attributes
  - Modal dialogs
  - Buttons and links
  - Form inputs
- Screen reader support
  - Landmark regions
  - Decorative elements hidden
  - Descriptive text
- Color contrast
- Click target sizes (minimum 44x44px)

## Best Practices

1. **Test Organization**: Tests are organized by feature/component
2. **Descriptive Test Names**: Use clear, descriptive test names that explain what is being tested
3. **Wait Strategies**: Use Playwright's auto-waiting features instead of hard waits
4. **Selectors**: Prefer semantic selectors (role, label, text) over CSS selectors
5. **Isolation**: Each test should be independent and not rely on other tests
6. **Cleanup**: Use beforeEach/afterEach for setup and teardown
7. **Assertions**: Use specific assertions that clearly indicate what is expected

## Configuration

The Playwright configuration is in `playwright.config.ts`:

- **Base URL**: http://localhost:3000
- **Test Directory**: `./e2e`
- **Browsers**: Chromium, Firefox, WebKit
- **Mobile**: iPhone 12, Pixel 5
- **Retries**: 2 on CI, 0 locally
- **Screenshots**: On failure only
- **Trace**: On first retry
- **Dev Server**: Automatically starts Next.js dev server

## Debugging Tests

### Using the Playwright Inspector
```bash
npm run test:e2e:debug
```

This opens the Playwright Inspector, allowing you to:
- Step through tests
- Inspect DOM
- View console logs
- See network requests

### Using UI Mode (Recommended)
```bash
npm run test:e2e:ui
```

UI mode provides:
- Visual test runner
- Watch mode
- Time travel debugging
- Network inspection
- Trace viewer

### View Screenshots and Videos
After test failures, check:
- `test-results/` - Screenshots and traces
- `playwright-report/` - HTML report with details

## CI/CD Integration

Tests can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Install dependencies
  run: npm ci

- name: Install Playwright browsers
  run: npx playwright install --with-deps

- name: Run E2E tests
  run: npm run test:e2e

- name: Upload test results
  if: always()
  uses: actions/upload-artifact@v3
  with:
    name: playwright-report
    path: playwright-report/
```

## Writing New Tests

When adding new tests:

1. Create a new spec file in `e2e/` directory
2. Follow the naming convention: `feature-name.spec.ts`
3. Use `test.describe()` to group related tests
4. Use `test.beforeEach()` for common setup
5. Write clear, focused test cases
6. Test both happy paths and error cases
7. Include accessibility checks
8. Test responsive behavior when relevant

Example:
```typescript
import { test, expect } from '@playwright/test';

test.describe('New Feature', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/new-feature');
  });

  test('should display feature correctly', async ({ page }) => {
    await expect(page.getByRole('heading', { name: /feature title/i })).toBeVisible();
  });

  test('should handle user interaction', async ({ page }) => {
    await page.getByRole('button', { name: /action/i }).click();
    await expect(page.getByText(/success message/i)).toBeVisible();
  });
});
```

## Troubleshooting

### Tests are flaky
- Ensure proper wait strategies
- Check for race conditions
- Use `waitForLoadState` if needed
- Increase timeouts for slow operations

### Tests fail in CI but pass locally
- Check browser versions
- Verify environment variables
- Check viewport sizes
- Review CI-specific configuration

### Modal tests fail
- Ensure modals have proper ARIA attributes
- Check z-index layering
- Verify backdrop click handlers

### Form tests fail
- Verify input labels and IDs match
- Check validation logic
- Ensure error messages are accessible

## Resources

- [Playwright Documentation](https://playwright.dev/)
- [Best Practices](https://playwright.dev/docs/best-practices)
- [Accessibility Testing](https://playwright.dev/docs/accessibility-testing)
- [API Reference](https://playwright.dev/docs/api/class-playwright)
