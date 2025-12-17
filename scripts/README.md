# Stripe Provisioning Scripts

This directory contains automated scripts for provisioning and managing Stripe resources for the Talkies SaaS platform.

## Overview

The provisioning system uses a **configuration-as-code** approach with TOML files to define all Stripe resources. This ensures:

- **Idempotency**: Safe to run multiple times without creating duplicates
- **Version Control**: Configuration is stored in Git
- **Reproducibility**: Same config produces same results across environments
- **Documentation**: Config file serves as documentation of your Stripe setup

## Files

- **`stripe_config.toml`**: Configuration file defining all Stripe resources
- **`provision_stripe.py`**: Main provisioning script
- **`requirements.txt`**: Python dependencies
- **`README.md`**: This documentation

## Quick Start

### 1. Install Dependencies

```bash
# Using pip
pip install -r requirements.txt

# Or using uv (recommended)
uv pip install -r requirements.txt
```

**Note**: Requires Python 3.11+ for native TOML support (`tomllib`).

### 2. Set Environment Variables

```bash
# For test mode
export STRIPE_TEST_SECRET_KEY=sk_test_...

# For live mode (production)
export STRIPE_LIVE_SECRET_KEY=sk_live_...
```

**Security**: Never commit API keys to version control. Use environment variables or a secret manager.

### 3. Run Provisioning

```bash
# Test mode (safe, uses test Stripe account)
python provision_stripe.py --mode test

# Live mode (production - requires confirmation)
python provision_stripe.py --mode live --confirm
```

### 4. Save Webhook Secret

After provisioning, the script outputs a webhook signing secret. Save it to your environment:

```bash
# Add to your .env file or secrets manager
STRIPE_TEST_WEBHOOK_SECRET=whsec_...
STRIPE_LIVE_WEBHOOK_SECRET=whsec_...
```

### 5. Use Generated Configuration

The script creates `stripe_config_test.json` or `stripe_config_live.json` with all resource IDs. Use these in your application:

```json
{
  "mode": "test",
  "created_at": "2025-01-15T10:30:00",
  "products": {
    "talkies_pro": {
      "id": "prod_xxxxx",
      "name": "Talkies Pro"
    }
  },
  "prices": {
    "talkies_pro_monthly": {
      "id": "price_xxxxx",
      "lookup_key": "talkies_pro_monthly",
      "unit_amount": 1999,
      "currency": "usd"
    }
  },
  "webhook": {
    "id": "we_xxxxx",
    "url": "https://api.talkies.app/webhooks/stripe-test",
    "secret": "whsec_xxxxx"
  }
}
```

## Configuration File

### Structure

The `stripe_config.toml` file defines:

1. **Products**: Your subscription tiers (Free, Pro, Enterprise)
2. **Prices**: Billing options (monthly, annual, lifetime)
3. **Webhooks**: Events to listen for
4. **Customer Portal**: Self-service subscription management
5. **Tax Settings**: Stripe Tax configuration
6. **Promotion Codes**: Discount codes and coupons

### Example Product Definition

```toml
[[products]]
id = "talkies_pro"
name = "Talkies Pro"
description = "Full access with unlimited minutes"
active = true

[products.metadata]
tier = "pro"
features = "unlimited_transcription,cloud_storage,priority_support"
max_minutes_per_month = "unlimited"
storage_gb = "100"
```

### Example Price Definition

```toml
[[prices]]
lookup_key = "talkies_pro_monthly"
product = "talkies_pro"
currency = "usd"
unit_amount = 1999  # $19.99

[prices.recurring]
interval = "month"
interval_count = 1
trial_period_days = 14

[prices.metadata]
plan_name = "Pro Monthly"
billing_cycle = "monthly"
display_price = "$19.99/mo"
```

## Script Features

### Idempotency

The script uses several strategies to prevent duplicates:

- **Idempotency Keys**: All create operations use unique keys
- **Lookup Keys**: Prices are referenced by human-readable names
- **Metadata Matching**: Products are matched by tier metadata
- **Existence Checks**: Webhooks and promo codes are checked before creation

Safe to run multiple times - existing resources are detected and skipped.

### Error Handling

- **API Errors**: Stripe errors are caught and displayed with helpful messages
- **Rate Limiting**: Idempotency keys make retries safe
- **Partial Failures**: Script continues if non-critical resources fail
- **Validation**: Configuration is validated before API calls

### Modes

**Test Mode** (`--mode test`):
- Uses `sk_test_...` API key
- Creates resources in Stripe test mode
- Safe to experiment with
- No real charges

**Live Mode** (`--mode live --confirm`):
- Uses `sk_live_...` API key
- Creates resources in production Stripe account
- Requires `--confirm` flag
- Requires manual "yes" confirmation
- **Use with caution**

## Usage Examples

### Basic Usage

```bash
# Provision test environment
python provision_stripe.py --mode test

# Provision production (with safety checks)
python provision_stripe.py --mode live --confirm
```

### Custom Configuration

```bash
# Use a different config file
python provision_stripe.py --mode test --config custom_config.toml
```

### Workflow Example

```bash
# 1. Edit configuration
vim stripe_config.toml

# 2. Test in test mode
python provision_stripe.py --mode test

# 3. Verify in Stripe Dashboard
# https://dashboard.stripe.com/test/products

# 4. Deploy to production
python provision_stripe.py --mode live --confirm

# 5. Save outputs
cat stripe_config_live.json
```

## What Gets Created

### Products (3)

1. **Talkies Free**: Basic tier with limited features
2. **Talkies Pro**: Full-featured tier with unlimited usage
3. **Talkies Enterprise**: Enterprise tier with custom features

### Prices (4+)

- Pro Monthly: $19.99/month with 14-day trial
- Pro Annual: $199/year (17% discount) with 14-day trial
- Pro Lifetime: $499 one-time payment
- Enterprise Monthly: $99/month (contact sales)

### Customer Portal

Self-service portal where customers can:
- Update email, address, phone, tax ID
- View invoice history
- Update payment methods
- Cancel subscriptions (at period end)
- Upgrade/downgrade plans (Pro monthly ↔ annual)

### Webhook Endpoint

Listens for 20+ event types:
- Subscription lifecycle (created, updated, deleted, trial ending)
- Payment events (succeeded, failed, refunded)
- Customer events (created, updated, deleted)
- Checkout events (completed, expired)

### Tax Settings

- Stripe Tax enabled (automatic tax calculation)
- Tax behavior: Exclusive (tax added on top of price)
- Tax code: `txcd_10000000` (Software as a Service)

### Promotion Codes (4)

1. **TALKIES20**: 20% off first payment (launch campaign)
2. **ANNUAL30**: 30% off annual plans
3. **TRIAL30**: Extended 30-day trial
4. **LIFETIME50**: 50% off lifetime plan

## Integration

### Frontend Integration

```typescript
// Use price IDs from stripe_config_live.json
const PRICE_IDS = {
  pro_monthly: "price_xxxxx",
  pro_annual: "price_xxxxx",
  pro_lifetime: "price_xxxxx",
};

// Create checkout session
const session = await stripe.checkout.sessions.create({
  mode: "subscription",
  line_items: [
    {
      price: PRICE_IDS.pro_monthly,
      quantity: 1,
    },
  ],
  success_url: "https://talkies.app/success?session_id={CHECKOUT_SESSION_ID}",
  cancel_url: "https://talkies.app/pricing",
  automatic_tax: { enabled: true },
});
```

### Backend Integration

```python
import stripe
import os

# Load webhook secret from environment
webhook_secret = os.getenv("STRIPE_LIVE_WEBHOOK_SECRET")

# Verify webhook signature
@app.route("/webhooks/stripe", methods=["POST"])
def stripe_webhook():
    payload = request.data
    sig_header = request.headers.get("Stripe-Signature")

    try:
        event = stripe.Webhook.construct_event(
            payload, sig_header, webhook_secret
        )
    except ValueError:
        return "Invalid payload", 400
    except stripe.error.SignatureVerificationError:
        return "Invalid signature", 400

    # Handle event
    if event.type == "customer.subscription.created":
        handle_subscription_created(event.data.object)
    elif event.type == "invoice.paid":
        handle_invoice_paid(event.data.object)

    return "Success", 200
```

### Customer Portal Integration

```typescript
// Create portal session for customer
const session = await stripe.billingPortal.sessions.create({
  customer: "cus_xxxxx",
  return_url: "https://talkies.app/dashboard",
});

// Redirect to portal
window.location.href = session.url;
```

## Maintenance

### Updating Prices

**Important**: You cannot modify a price's amount after creation. To change pricing:

1. Create a new price in `stripe_config.toml`
2. Set a new `lookup_key` (e.g., `talkies_pro_monthly_v2`)
3. Run provisioning: `python provision_stripe.py --mode test`
4. Update your application to use the new price ID
5. Optionally deactivate the old price in Stripe Dashboard

### Updating Products

Products can be updated directly:

1. Modify product in `stripe_config.toml`
2. Run provisioning again
3. Existing products will be matched by metadata and updated

### Adding New Promo Codes

1. Add new `[[promo_codes]]` section to `stripe_config.toml`
2. Run provisioning
3. New codes are created, existing codes are skipped

### Updating Webhooks

1. Modify `[webhooks]` section to add/remove events
2. Run provisioning
3. Note: Creates new webhook - manually delete old one in Dashboard

## Troubleshooting

### "Stripe API key not found"

**Solution**: Set environment variable for your mode:
```bash
export STRIPE_TEST_SECRET_KEY=sk_test_...
# or
export STRIPE_LIVE_SECRET_KEY=sk_live_...
```

### "Configuration file not found"

**Solution**: Ensure you're in the `scripts/` directory or provide full path:
```bash
python provision_stripe.py --config /path/to/stripe_config.toml
```

### "Price already exists with this lookup_key"

**Solution**: Either:
1. Delete the existing price in Stripe Dashboard
2. Change the `lookup_key` in your config to create a new price
3. Let the script skip it (idempotent behavior)

### "Invalid API version"

**Solution**: Update the `api_version` in `stripe_config.toml` to a valid Stripe API version.

### "Cannot enable Stripe Tax"

**Solution**: Stripe Tax requires manual activation:
1. Go to Stripe Dashboard → Settings → Tax
2. Click "Activate Stripe Tax"
3. Run provisioning again

## Best Practices

### Development Workflow

1. **Always test in test mode first**
   ```bash
   python provision_stripe.py --mode test
   ```

2. **Review changes in Stripe Dashboard**
   - Test mode: https://dashboard.stripe.com/test/products
   - Live mode: https://dashboard.stripe.com/products

3. **Verify webhook integration**
   ```bash
   # Use Stripe CLI for local testing
   stripe listen --forward-to localhost:3000/webhooks/stripe
   stripe trigger customer.subscription.created
   ```

4. **Deploy to production carefully**
   ```bash
   # Double-check configuration
   python provision_stripe.py --mode live --confirm
   ```

### Security

- **Never commit API keys** to version control
- **Store webhook secrets securely** (environment variables or secret manager)
- **Use separate keys** for test and live modes
- **Rotate API keys** if compromised
- **Restrict API key permissions** in Stripe Dashboard

### Version Control

- **Commit `stripe_config.toml`** to track configuration changes
- **Ignore `*.json` output files** (they contain secrets)
- **Document changes** in commit messages
- **Tag releases** when deploying to production

### Monitoring

- **Monitor webhook delivery** in Stripe Dashboard → Developers → Webhooks
- **Set up alerts** for failed payments and subscription cancellations
- **Track metrics** in Stripe Dashboard → Reports
- **Review event logs** regularly

## Environment Variables Reference

### Required

- `STRIPE_TEST_SECRET_KEY`: Test mode secret API key
- `STRIPE_LIVE_SECRET_KEY`: Live mode secret API key (production)

### Generated (save after provisioning)

- `STRIPE_TEST_WEBHOOK_SECRET`: Test mode webhook signing secret
- `STRIPE_LIVE_WEBHOOK_SECRET`: Live mode webhook signing secret

### Optional

- `STRIPE_TEST_PUBLISHABLE_KEY`: Test mode publishable key (frontend)
- `STRIPE_LIVE_PUBLISHABLE_KEY`: Live mode publishable key (frontend)

## Resources

### Stripe Documentation

- [Stripe API Reference](https://docs.stripe.com/api)
- [Products & Prices](https://docs.stripe.com/products-prices)
- [Customer Portal](https://docs.stripe.com/customer-management/integrate-customer-portal)
- [Webhooks](https://docs.stripe.com/webhooks)
- [Stripe Tax](https://docs.stripe.com/tax)
- [Testing](https://docs.stripe.com/testing)

### Tools

- [Stripe Dashboard](https://dashboard.stripe.com/)
- [Stripe CLI](https://stripe.com/docs/stripe-cli)
- [API Logs](https://dashboard.stripe.com/logs)

### Support

- [Stripe Support](https://support.stripe.com/)
- [Community Forum](https://community.stripe.com/)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/stripe-payments)

## Contributing

### Reporting Issues

If you encounter issues with the provisioning script:

1. Check this README for troubleshooting steps
2. Verify your environment variables are set correctly
3. Check Stripe API logs for detailed error messages
4. Open an issue with:
   - Error message
   - Command you ran
   - Relevant config sections
   - Stripe API version

### Improving Configuration

To suggest improvements to the default configuration:

1. Fork the repository
2. Modify `stripe_config.toml`
3. Test in test mode
4. Submit a pull request with:
   - Description of changes
   - Rationale
   - Test results

## License

This script is part of the Talkies project. See the main repository LICENSE file for details.

## Version History

- **v1.0** (2025-01-15): Initial release
  - TOML-based configuration
  - Idempotent provisioning
  - Test/live mode support
  - Comprehensive error handling
  - Full Stripe resource coverage

---

**Last Updated**: 2025-01-15
**Stripe API Version**: 2024-12-18.acacia
**Python Version**: 3.11+
