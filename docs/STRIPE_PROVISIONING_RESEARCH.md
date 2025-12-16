# Stripe API Provisioning Research

This document provides comprehensive guidance on programmatically configuring Stripe for the Talkies SaaS platform using the Stripe API and Python SDK.

## Table of Contents

1. [Products & Prices API](#1-products--prices-api)
2. [Customer Portal Configuration API](#2-customer-portal-configuration-api)
3. [Webhook Endpoints API](#3-webhook-endpoints-api)
4. [Tax Rates & Tax Settings API](#4-tax-rates--tax-settings-api)
5. [Checkout Session Configuration](#5-checkout-session-configuration)
6. [Best Practices](#6-best-practices)
7. [Complete Provisioning Script](#7-complete-provisioning-script)

---

## 1. Products & Prices API

### Overview

Products represent the items or services you sell, while Prices define how much and how often customers are charged for those products. A single Product can have multiple Prices (e.g., monthly vs. annual plans, different currencies, or price changes over time).

### Product Object

**Key Fields:**
- `name` (required): Display name shown to customers
- `description`: Long-form explanation of what you're selling
- `metadata`: Up to 50 key-value pairs (keys max 40 chars, values max 500 chars)
- `id`: Custom ID (optional - Stripe generates one if not provided)
- `active`: Whether the product is currently available (default: `true`)

### Creating a Product

**Python SDK Example:**

```python
import stripe

stripe.api_key = "sk_test_..."

# Create a product
product = stripe.Product.create(
    name="Talkies Pro Plan",
    description="Full access to Talkies voice transcription with unlimited minutes",
    metadata={
        "plan_tier": "pro",
        "features": "unlimited_transcription,cloud_storage,priority_support",
        "internal_plan_id": "PRO_001"
    }
)

print(f"Product created: {product.id}")
```

**cURL Example:**

```bash
curl https://api.stripe.com/v1/products \
  -u sk_test_...: \
  -d name="Talkies Pro Plan" \
  -d description="Full access to Talkies voice transcription" \
  -d "metadata[plan_tier]"=pro
```

### Price Object

**Key Fields:**
- `currency` (required): Three-letter ISO code (e.g., "usd", "eur", "gbp")
- `product` (required): Product ID this price belongs to
- `unit_amount`: Price in cents (e.g., 1999 = $19.99) - OR -
- `unit_amount_decimal`: For sub-cent precision
- `recurring`: Object defining billing interval
  - `interval`: "day", "week", "month", or "year"
  - `interval_count`: Number of intervals (e.g., 3 for quarterly)
  - `usage_type`: "licensed" or "metered"
  - `trial_period_days`: Number of days for free trial
- `lookup_key`: Human-readable reference (e.g., "pro_monthly")
- `tax_behavior`: "inclusive", "exclusive", or "unspecified"
- `metadata`: Additional data storage

### Creating Prices

**Recurring Price (Subscription):**

```python
# Monthly subscription price
monthly_price = stripe.Price.create(
    product=product.id,
    currency="usd",
    unit_amount=1999,  # $19.99
    recurring={
        "interval": "month",
        "interval_count": 1,
        "trial_period_days": 14  # 14-day free trial
    },
    lookup_key="talkies_pro_monthly",
    tax_behavior="exclusive",  # Tax added on top
    metadata={
        "plan_name": "Pro Monthly",
        "billing_cycle": "monthly"
    }
)

# Annual subscription price (with discount)
annual_price = stripe.Price.create(
    product=product.id,
    currency="usd",
    unit_amount=19900,  # $199/year (save $39.88)
    recurring={
        "interval": "year",
        "interval_count": 1
    },
    lookup_key="talkies_pro_annual",
    tax_behavior="exclusive",
    metadata={
        "plan_name": "Pro Annual",
        "billing_cycle": "annual",
        "discount_percentage": "17"
    }
)
```

**One-Time Price:**

```python
# One-time setup fee
setup_price = stripe.Price.create(
    product="prod_setup_fee",
    currency="usd",
    unit_amount=4900,  # $49
    lookup_key="talkies_setup_fee",
    metadata={
        "price_type": "one_time_setup"
    }
)
```

**Tiered Pricing (Usage-Based):**

```python
# Metered billing for transcription minutes
metered_price = stripe.Price.create(
    product="prod_transcription_minutes",
    currency="usd",
    recurring={
        "interval": "month",
        "usage_type": "metered"
    },
    billing_scheme="tiered",
    tiers=[
        {
            "up_to": 100,
            "unit_amount": 0  # First 100 minutes free
        },
        {
            "up_to": 1000,
            "unit_amount": 10  # $0.10/minute for 101-1000
        },
        {
            "up_to": "inf",
            "unit_amount": 5   # $0.05/minute for 1000+
        }
    ],
    tiers_mode="graduated",
    lookup_key="talkies_metered_minutes"
)
```

### Price Lookup Keys

Lookup keys allow you to reference prices by human-readable names instead of Stripe IDs, making it easier to manage price changes.

**Using Lookup Keys:**

```python
# Create price with lookup key
stripe.Price.create(
    product="prod_xxx",
    currency="usd",
    unit_amount=2999,
    recurring={"interval": "month"},
    lookup_key="standard_monthly"
)

# Later, retrieve by lookup key
prices = stripe.Price.list(lookup_keys=["standard_monthly"])
price = prices.data[0]

# Update pricing: create new price and transfer lookup key
new_price = stripe.Price.create(
    product="prod_xxx",
    currency="usd",
    unit_amount=3499,  # New price
    recurring={"interval": "month"},
    lookup_key="standard_monthly",
    transfer_lookup_key=True  # Takes lookup key from old price
)
```

**Note:** You cannot change a price's amount via the API. Instead, create a new price and optionally deactivate the old one.

### Multi-Currency Support

```python
# Create prices in multiple currencies
currencies = ["usd", "eur", "gbp", "cad"]
prices = {}

for currency in currencies:
    # Apply currency-specific pricing
    amount_map = {
        "usd": 1999,
        "eur": 1899,
        "gbp": 1699,
        "cad": 2499
    }

    price = stripe.Price.create(
        product=product.id,
        currency=currency,
        unit_amount=amount_map[currency],
        recurring={"interval": "month"},
        lookup_key=f"pro_monthly_{currency}",
        metadata={"currency_code": currency.upper()}
    )
    prices[currency] = price.id

print(f"Created prices in {len(currencies)} currencies")
```

### Updating Products and Prices

**Update Product:**

```python
# Products can be fully updated
stripe.Product.modify(
    "prod_xxx",
    name="Talkies Pro Plan (Updated)",
    description="New description",
    metadata={"updated_at": "2025-01-15"}
)
```

**Update Price (Limited):**

```python
# Only metadata, nickname, and active fields can be updated
stripe.Price.modify(
    "price_xxx",
    active=False,  # Deactivate old price
    metadata={"deprecated": "true", "replaced_by": "price_yyy"}
)
```

---

## 2. Customer Portal Configuration API

### Overview

The Customer Portal allows customers to self-manage their subscriptions, payment methods, and billing information. You can configure the portal entirely in the Dashboard or use the API for advanced scenarios like multiple configurations per customer type or per connected account.

### Portal Configuration Object

**Key Features:**
- **business_profile**: Business name, privacy policy URL, terms of service URL
- **features**: Control what customers can do
  - `customer_update`: Allow email, address, phone updates
  - `invoice_history`: View past invoices
  - `payment_method_update`: Update payment methods
  - `subscription_cancel`: Cancel subscriptions
  - `subscription_pause`: Pause subscriptions
  - `subscription_update`: Change plans or quantities
- **default_return_url**: Where to redirect after portal actions
- **metadata**: Custom data storage

### Creating a Portal Configuration

**Python SDK Example:**

```python
# Create a custom portal configuration
portal_config = stripe.billing_portal.Configuration.create(
    business_profile={
        "headline": "Manage your Talkies subscription",
        "privacy_policy_url": "https://talkies.app/privacy",
        "terms_of_service_url": "https://talkies.app/terms"
    },
    features={
        "customer_update": {
            "enabled": True,
            "allowed_updates": ["email", "address", "phone", "tax_id"]
        },
        "invoice_history": {
            "enabled": True
        },
        "payment_method_update": {
            "enabled": True
        },
        "subscription_cancel": {
            "enabled": True,
            "mode": "at_period_end",  # Cancel at end of billing period
            "cancellation_reason": {
                "enabled": True,
                "options": [
                    "too_expensive",
                    "missing_features",
                    "switched_service",
                    "unused",
                    "customer_service",
                    "too_complex",
                    "low_quality",
                    "other"
                ]
            }
        },
        "subscription_pause": {
            "enabled": False  # Disable pausing for now
        },
        "subscription_update": {
            "enabled": True,
            "default_allowed_updates": ["price", "quantity"],
            "products": [
                {
                    "product": product_id,
                    "prices": [monthly_price_id, annual_price_id]
                }
            ],
            "proration_behavior": "always_invoice"  # or "create_prorations", "none"
        }
    },
    default_return_url="https://talkies.app/dashboard",
    metadata={
        "config_version": "1.0",
        "environment": "production"
    }
)

print(f"Portal configuration created: {portal_config.id}")
```

### Using Multiple Configurations

```python
# Create different configs for different customer segments

# Basic tier - limited options
basic_config = stripe.billing_portal.Configuration.create(
    business_profile={"headline": "Manage your Basic plan"},
    features={
        "subscription_cancel": {"enabled": True, "mode": "at_period_end"},
        "payment_method_update": {"enabled": True}
    }
)

# Enterprise tier - more flexibility
enterprise_config = stripe.billing_portal.Configuration.create(
    business_profile={"headline": "Manage your Enterprise plan"},
    features={
        "subscription_cancel": {"enabled": True, "mode": "immediately"},
        "subscription_pause": {"enabled": True},
        "subscription_update": {"enabled": True}
    }
)

# Store config IDs in customer metadata
stripe.Customer.modify(
    customer_id,
    metadata={"portal_config_id": enterprise_config.id}
)
```

### Creating a Portal Session

```python
# Create a session to redirect customer to portal
session = stripe.billing_portal.Session.create(
    customer="cus_xxx",
    configuration=portal_config.id,  # Optional: use specific config
    return_url="https://talkies.app/dashboard"
)

# Redirect customer to session.url
print(f"Portal URL: {session.url}")
```

### Updating Configuration

```python
# Update existing configuration
stripe.billing_portal.Configuration.modify(
    portal_config.id,
    features={
        "subscription_pause": {
            "enabled": True  # Enable pausing
        }
    }
)
```

### Listing Configurations

```python
# List all portal configurations
configs = stripe.billing_portal.Configuration.list(
    active=True,  # Only active configs
    limit=10
)

for config in configs.data:
    is_default = config.is_default
    print(f"Config {config.id}: default={is_default}")
```

---

## 3. Webhook Endpoints API

### Overview

Webhooks notify your application when events occur in your Stripe account. You can create webhook endpoints programmatically to automate infrastructure provisioning.

### Webhook Endpoint Object

**Key Fields:**
- `url` (required): HTTPS endpoint to receive events
- `enabled_events` (required): Array of event types or `["*"]` for all
- `api_version`: Stripe API version for event generation
- `description`: Human-readable description
- `metadata`: Additional data storage
- `connect`: Boolean (true for Connect webhooks)

### Important Webhook Events for SaaS

**Subscription Events:**
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `customer.subscription.paused`
- `customer.subscription.resumed`
- `customer.subscription.trial_will_end` (3 days before trial ends)

**Payment Events:**
- `invoice.created`
- `invoice.finalized`
- `invoice.paid`
- `invoice.payment_failed`
- `invoice.payment_action_required`
- `charge.succeeded`
- `charge.failed`
- `charge.refunded`

**Customer Events:**
- `customer.created`
- `customer.updated`
- `customer.deleted`

**Payment Method Events:**
- `payment_method.attached`
- `payment_method.detached`
- `payment_method.updated`

### Creating a Webhook Endpoint

**Python SDK Example:**

```python
# Create webhook endpoint for production
webhook = stripe.WebhookEndpoint.create(
    url="https://api.talkies.app/webhooks/stripe",
    enabled_events=[
        # Subscription lifecycle
        "customer.subscription.created",
        "customer.subscription.updated",
        "customer.subscription.deleted",
        "customer.subscription.trial_will_end",

        # Payment events
        "invoice.paid",
        "invoice.payment_failed",
        "invoice.payment_action_required",
        "charge.succeeded",
        "charge.failed",

        # Customer events
        "customer.created",
        "customer.updated",
        "customer.deleted",

        # Payment method changes
        "payment_method.attached",
        "payment_method.detached"
    ],
    api_version="2024-12-18.acacia",  # Use specific API version
    description="Talkies production webhook",
    metadata={
        "environment": "production",
        "service": "talkies-api",
        "region": "us-east-1"
    }
)

# IMPORTANT: Store the signing secret securely
signing_secret = webhook.secret
print(f"Webhook created: {webhook.id}")
print(f"Signing secret: {signing_secret}")  # Store in environment variables
```

### Listen to All Events

```python
# Listen to all events (use cautiously)
webhook_all = stripe.WebhookEndpoint.create(
    url="https://api.talkies.app/webhooks/stripe-all",
    enabled_events=["*"],
    description="Talkies catch-all webhook for monitoring"
)
```

### Connect Webhooks

```python
# Create Connect webhook for platform
connect_webhook = stripe.WebhookEndpoint.create(
    url="https://api.talkies.app/webhooks/stripe-connect",
    enabled_events=[
        "account.updated",
        "account.application.authorized",
        "account.application.deauthorized"
    ],
    connect=True,  # Connect webhook
    description="Talkies Connect webhook"
)
```

### Verifying Webhook Signatures

**Security Implementation:**

```python
import stripe
from flask import request, jsonify

@app.route('/webhooks/stripe', methods=['POST'])
def stripe_webhook():
    payload = request.data
    sig_header = request.headers.get('Stripe-Signature')
    webhook_secret = os.environ['STRIPE_WEBHOOK_SECRET']

    try:
        # Verify webhook signature
        event = stripe.Webhook.construct_event(
            payload, sig_header, webhook_secret
        )
    except ValueError as e:
        # Invalid payload
        return jsonify({'error': 'Invalid payload'}), 400
    except stripe.error.SignatureVerificationError as e:
        # Invalid signature
        return jsonify({'error': 'Invalid signature'}), 400

    # Handle the event
    event_type = event['type']
    event_data = event['data']['object']

    if event_type == 'customer.subscription.created':
        handle_subscription_created(event_data)
    elif event_type == 'invoice.paid':
        handle_invoice_paid(event_data)
    elif event_type == 'invoice.payment_failed':
        handle_payment_failed(event_data)

    return jsonify({'status': 'success'}), 200
```

### Managing Webhook Endpoints

**List Webhooks:**

```python
# List all webhook endpoints
webhooks = stripe.WebhookEndpoint.list(limit=100)

for webhook in webhooks.data:
    print(f"ID: {webhook.id}, URL: {webhook.url}, Status: {webhook.status}")
```

**Update Webhook:**

```python
# Update webhook events
stripe.WebhookEndpoint.modify(
    webhook.id,
    enabled_events=[
        "customer.subscription.created",
        "customer.subscription.deleted",
        "invoice.paid"
    ],
    description="Updated webhook configuration"
)
```

**Delete Webhook:**

```python
# Delete webhook endpoint
stripe.WebhookEndpoint.delete(webhook.id)
print(f"Deleted webhook: {webhook.id}")
```

### Webhook Retry Behavior

- **Live Mode**: Stripe retries failed webhooks for up to 3 days with exponential backoff
- **Test Mode**: Stripe retries 3 times over a few hours
- **Recommendation**: Implement idempotent webhook handlers to safely handle duplicate events

### Testing Webhooks Locally

```python
# Use Stripe CLI for local testing
# stripe listen --forward-to localhost:3000/webhooks/stripe

# Trigger test events
# stripe trigger customer.subscription.created
```

---

## 4. Tax Rates & Tax Settings API

### Overview

Stripe provides two approaches to tax:
1. **Manual Tax Rates**: You define and manage specific tax rates
2. **Stripe Tax (Automatic)**: Stripe automatically calculates tax based on customer location and your registrations

### Stripe Tax (Recommended for SaaS)

**Tax Settings API** allows programmatic configuration without using the Dashboard.

### Setting Up Stripe Tax

**Enable Stripe Tax:**

```python
# Check if Stripe Tax is set up
tax_settings = stripe.tax.Settings.retrieve()

if tax_settings.status != "active":
    # Update tax settings to activate
    tax_settings = stripe.tax.Settings.update(
        defaults={
            "tax_behavior": "exclusive",  # Tax added on top of price
            "tax_code": "txcd_10000000"   # Software as a Service (SaaS)
        }
    )

print(f"Stripe Tax status: {tax_settings.status}")
```

### Tax Registrations

Before collecting tax, register with local tax authorities and add registrations to Stripe.

**Add Tax Registration:**

```python
# Register for sales tax collection in a region
registration = stripe.tax.Registration.create(
    country="US",
    country_options={
        "us": {
            "type": "state_sales_tax",
            "state": "CA"  # California
        }
    },
    active_from=int(datetime(2025, 1, 1).timestamp())
)

print(f"Tax registration created: {registration.id}")
```

**Multi-Region Registration:**

```python
# Register in multiple US states
states = ["CA", "NY", "TX", "FL", "WA"]

for state in states:
    stripe.tax.Registration.create(
        country="US",
        country_options={
            "us": {
                "type": "state_sales_tax",
                "state": state
            }
        },
        active_from=int(datetime(2025, 1, 1).timestamp())
    )
    print(f"Registered in {state}")
```

### Using Stripe Tax in Checkout

```python
# Enable automatic tax in Checkout Session
session = stripe.checkout.Session.create(
    mode="subscription",
    line_items=[{
        "price": "price_xxx",
        "quantity": 1
    }],
    automatic_tax={
        "enabled": True  # Stripe calculates tax automatically
    },
    success_url="https://talkies.app/success",
    cancel_url="https://talkies.app/pricing"
)
```

### Manual Tax Rates (Legacy Approach)

If you prefer manual control, create and apply tax rates explicitly.

**Create Tax Rate:**

```python
# Create a tax rate
tax_rate = stripe.TaxRate.create(
    display_name="CA Sales Tax",
    description="California sales tax",
    jurisdiction="US - CA",
    percentage=7.25,  # 7.25%
    inclusive=False,  # Tax added on top
    active=True,
    metadata={
        "state": "CA",
        "type": "sales_tax"
    }
)

print(f"Tax rate created: {tax_rate.id}")
```

**Apply Tax Rate to Subscription:**

```python
# Create subscription with manual tax rates
subscription = stripe.Subscription.create(
    customer="cus_xxx",
    items=[{"price": "price_xxx"}],
    default_tax_rates=[tax_rate.id]
)
```

**Apply Tax Rate in Checkout:**

```python
# Checkout with manual tax rates
session = stripe.checkout.Session.create(
    mode="subscription",
    line_items=[{
        "price": "price_xxx",
        "quantity": 1,
        "tax_rates": [tax_rate.id]
    }],
    success_url="https://talkies.app/success",
    cancel_url="https://talkies.app/pricing"
)
```

### Tax Behavior Options

When creating prices, specify how tax is handled:

```python
# Tax exclusive (default) - tax added on top
price_exclusive = stripe.Price.create(
    product="prod_xxx",
    currency="usd",
    unit_amount=1999,  # $19.99 + tax
    recurring={"interval": "month"},
    tax_behavior="exclusive"
)

# Tax inclusive - tax included in price
price_inclusive = stripe.Price.create(
    product="prod_xxx",
    currency="eur",
    unit_amount=2000,  # €20.00 including tax
    recurring={"interval": "month"},
    tax_behavior="inclusive"
)

# Automatic - Stripe decides based on currency
price_auto = stripe.Price.create(
    product="prod_xxx",
    currency="usd",
    unit_amount=1999,
    recurring={"interval": "month"},
    tax_behavior="automatic"  # Exclusive for USD/CAD, inclusive for others
)
```

### Tax Codes

Use tax codes to categorize your products for accurate tax calculation.

**Common SaaS Tax Codes:**
- `txcd_10000000`: Software as a Service (SaaS) - most common for Talkies
- `txcd_10103000`: Electronically supplied services
- `txcd_99999999`: General - Tangible Goods

```python
# Set tax code on product
stripe.Product.modify(
    product_id,
    tax_code="txcd_10000000"  # SaaS
)
```

---

## 5. Checkout Session Configuration

### Overview

Checkout Sessions create hosted payment pages for one-time purchases or subscriptions. While you cannot pre-configure default settings globally, you can create reusable patterns and store common configurations.

### Creating a Checkout Session

**Basic Subscription Checkout:**

```python
session = stripe.checkout.Session.create(
    mode="subscription",  # or "payment" for one-time

    # Line items (products/prices)
    line_items=[{
        "price": "price_xxx",  # Or use price_data for dynamic pricing
        "quantity": 1
    }],

    # URLs
    success_url="https://talkies.app/success?session_id={CHECKOUT_SESSION_ID}",
    cancel_url="https://talkies.app/pricing",

    # Customer options
    customer="cus_xxx",  # Existing customer
    # OR allow email input:
    # customer_email="user@example.com",
    # customer_creation="always",

    # Payment settings
    payment_method_types=["card"],  # Default: auto-detect optimal methods

    # Tax
    automatic_tax={"enabled": True},

    # Trial period
    subscription_data={
        "trial_period_days": 14,
        "metadata": {
            "plan": "pro",
            "source": "website"
        }
    },

    # Other options
    allow_promotion_codes=True,
    billing_address_collection="auto",  # or "required"
    locale="auto",  # Detect from browser

    # Metadata
    metadata={
        "integration": "talkies_web",
        "utm_source": "google_ads"
    }
)

print(f"Checkout URL: {session.url}")
```

### One-Time Payment Checkout

```python
session = stripe.checkout.Session.create(
    mode="payment",
    line_items=[{
        "price": "price_setup_fee",
        "quantity": 1
    }],
    success_url="https://talkies.app/success?session_id={CHECKOUT_SESSION_ID}",
    cancel_url="https://talkies.app/pricing",
    automatic_tax={"enabled": True}
)
```

### Dynamic Pricing in Checkout

```python
# Create price on-the-fly
session = stripe.checkout.Session.create(
    mode="subscription",
    line_items=[{
        "price_data": {
            "currency": "usd",
            "product": "prod_xxx",
            "unit_amount": 1999,
            "recurring": {
                "interval": "month"
            }
        },
        "quantity": 1
    }],
    success_url="https://talkies.app/success",
    cancel_url="https://talkies.app/pricing"
)
```

### Multiple Line Items

```python
# Subscription + one-time setup fee
session = stripe.checkout.Session.create(
    mode="subscription",
    line_items=[
        {
            "price": "price_subscription_monthly",
            "quantity": 1
        },
        {
            "price": "price_setup_fee",
            "quantity": 1
        }
    ],
    success_url="https://talkies.app/success",
    cancel_url="https://talkies.app/pricing"
)
```

### Promotion Codes

```python
# Create promotion code
coupon = stripe.Coupon.create(
    percent_off=20,
    duration="once",  # or "forever", "repeating"
    name="20% off first payment"
)

promo_code = stripe.PromotionCode.create(
    coupon=coupon.id,
    code="TALKIES20",
    metadata={"campaign": "launch_2025"}
)

# Enable in Checkout
session = stripe.checkout.Session.create(
    mode="subscription",
    line_items=[{"price": "price_xxx", "quantity": 1}],
    allow_promotion_codes=True,  # Customer can enter codes
    # OR pre-apply a code:
    # discounts=[{"promotion_code": promo_code.id}],
    success_url="https://talkies.app/success",
    cancel_url="https://talkies.app/pricing"
)
```

### Free Trials

```python
# Add trial to checkout
session = stripe.checkout.Session.create(
    mode="subscription",
    line_items=[{"price": "price_xxx", "quantity": 1}],
    subscription_data={
        "trial_period_days": 14,
        "trial_settings": {
            "end_behavior": {
                "missing_payment_method": "cancel"  # Cancel if no payment method
            }
        }
    },
    success_url="https://talkies.app/success",
    cancel_url="https://talkies.app/pricing",
    payment_method_collection="if_required"  # Don't require card for trial
)
```

### Collecting Addresses

```python
session = stripe.checkout.Session.create(
    mode="subscription",
    line_items=[{"price": "price_xxx", "quantity": 1}],
    billing_address_collection="required",
    shipping_address_collection={
        "allowed_countries": ["US", "CA", "GB", "AU"]
    },
    success_url="https://talkies.app/success",
    cancel_url="https://talkies.app/pricing"
)
```

### Payment Method Types

```python
# Default: Stripe auto-detects optimal payment methods
session = stripe.checkout.Session.create(
    mode="subscription",
    line_items=[{"price": "price_xxx", "quantity": 1}],
    # Omit payment_method_types for auto-detection
    success_url="https://talkies.app/success",
    cancel_url="https://talkies.app/pricing"
)

# Or specify explicitly
session = stripe.checkout.Session.create(
    mode="subscription",
    line_items=[{"price": "price_xxx", "quantity": 1}],
    payment_method_types=["card", "us_bank_account", "cashapp"],
    success_url="https://talkies.app/success",
    cancel_url="https://talkies.app/pricing"
)
```

### Session Expiration

```python
from datetime import datetime, timedelta

# Sessions expire after 24 hours by default
# You cannot extend this, but you can shorten it
session = stripe.checkout.Session.create(
    mode="subscription",
    line_items=[{"price": "price_xxx", "quantity": 1}],
    expires_at=int((datetime.now() + timedelta(hours=1)).timestamp()),
    success_url="https://talkies.app/success",
    cancel_url="https://talkies.app/pricing"
)
```

### Handling Checkout Completion

```python
# After checkout, retrieve session to get customer and subscription IDs
def handle_checkout_success(session_id):
    session = stripe.checkout.Session.retrieve(
        session_id,
        expand=["subscription", "customer"]
    )

    customer_id = session.customer.id
    subscription_id = session.subscription.id

    # Update your database
    # Grant access to the customer

    return {
        "customer": customer_id,
        "subscription": subscription_id
    }
```

---

## 6. Best Practices

### 6.1 Idempotency

Always use idempotency keys for POST requests to safely retry operations without duplicates.

**How Idempotency Works:**
1. Client generates unique key (e.g., UUID v4)
2. Stripe caches the result of the first request (success or failure)
3. Subsequent requests with the same key return the cached result

**Python SDK Implementation:**

```python
import uuid
import stripe

# Generate idempotency key
idempotency_key = str(uuid.uuid4())

# Use in request
customer = stripe.Customer.create(
    email="user@example.com",
    name="John Doe",
    metadata={"user_id": "12345"},
    idempotency_key=idempotency_key  # Ensures safe retry
)
```

**Manual Header:**

```bash
curl https://api.stripe.com/v1/customers \
  -u sk_test_...: \
  -H "Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000" \
  -d email="user@example.com"
```

**Key Specifications:**
- Up to 255 characters
- Automatically removed after 24 hours
- Use V4 UUIDs or similar high-entropy strings
- Only needed for POST requests (GET/DELETE are naturally idempotent)

**Error Handling:**

```python
import stripe
import uuid

def create_customer_safely(email, name, user_id, max_retries=3):
    """
    Safely create a customer with automatic retry and idempotency.
    """
    idempotency_key = str(uuid.uuid4())

    for attempt in range(max_retries):
        try:
            customer = stripe.Customer.create(
                email=email,
                name=name,
                metadata={"user_id": user_id},
                idempotency_key=idempotency_key
            )
            return customer
        except stripe.error.RateLimitError:
            # Retry with same idempotency key
            if attempt < max_retries - 1:
                time.sleep(2 ** attempt)  # Exponential backoff
                continue
            raise
        except stripe.error.APIConnectionError:
            # Network error - safe to retry with same key
            if attempt < max_retries - 1:
                time.sleep(2 ** attempt)
                continue
            raise
        except stripe.error.StripeError as e:
            # Other Stripe errors - log and raise
            print(f"Stripe error: {e.user_message}")
            raise
```

**When to Generate New Keys:**
- Always generate a new key if you're changing request parameters
- Generate new keys for 400-level errors (except 429 rate limits)
- Safe to reuse the same key for network failures and 429 errors

### 6.2 Test vs Live Mode

Stripe has separate test and live modes with different API keys and data.

**API Key Prefixes:**
- Test: `sk_test_...` (secret), `pk_test_...` (publishable)
- Live: `sk_live_...` (secret), `pk_live_...` (publishable)

**Environment Management:**

```python
import os
import stripe

# Set API key based on environment
ENVIRONMENT = os.getenv("ENVIRONMENT", "development")

if ENVIRONMENT == "production":
    stripe.api_key = os.getenv("STRIPE_LIVE_SECRET_KEY")
    WEBHOOK_SECRET = os.getenv("STRIPE_LIVE_WEBHOOK_SECRET")
else:
    stripe.api_key = os.getenv("STRIPE_TEST_SECRET_KEY")
    WEBHOOK_SECRET = os.getenv("STRIPE_TEST_WEBHOOK_SECRET")

print(f"Running in {ENVIRONMENT} mode")
```

**Testing Best Practices:**
1. Always develop with test keys first
2. Use Stripe CLI for local webhook testing: `stripe listen --forward-to localhost:3000/webhooks`
3. Test with [Stripe test cards](https://stripe.com/docs/testing):
   - Success: `4242424242424242`
   - Decline: `4000000000000002`
   - 3D Secure: `4000002500003155`
4. Trigger test webhooks: `stripe trigger customer.subscription.created`
5. Never commit API keys to version control

**Environment Variables (.env):**

```bash
# Development
STRIPE_TEST_SECRET_KEY=sk_test_...
STRIPE_TEST_PUBLISHABLE_KEY=pk_test_...
STRIPE_TEST_WEBHOOK_SECRET=whsec_...

# Production (use secret manager in production!)
STRIPE_LIVE_SECRET_KEY=sk_live_...
STRIPE_LIVE_PUBLISHABLE_KEY=pk_live_...
STRIPE_LIVE_WEBHOOK_SECRET=whsec_...
```

### 6.3 Metadata Conventions

Metadata is a powerful tool for linking Stripe objects to your internal systems.

**Limits:**
- Up to 50 key-value pairs per object
- Keys: max 40 characters (no square brackets)
- Values: max 500 characters
- Both stored as strings

**Recommended Conventions:**

```python
# Customer metadata
stripe.Customer.create(
    email="user@example.com",
    metadata={
        # Internal system IDs
        "user_id": "usr_12345",
        "account_id": "acct_67890",

        # User attributes
        "signup_date": "2025-01-15",
        "signup_source": "google_ads",
        "utm_campaign": "winter_2025",

        # Account tier
        "plan_tier": "pro",
        "is_enterprise": "false",

        # Features
        "features": "transcription,export,api_access",

        # Support
        "support_tier": "priority",
        "account_manager": "jane@talkies.app"
    }
)

# Subscription metadata
stripe.Subscription.create(
    customer="cus_xxx",
    items=[{"price": "price_xxx"}],
    metadata={
        "plan_name": "Pro Monthly",
        "billing_cycle": "monthly",
        "started_at": "2025-01-15T10:30:00Z",
        "trial_converted": "true",
        "discount_applied": "TALKIES20",
        "referral_code": "REF123"
    }
)

# Product metadata
stripe.Product.create(
    name="Talkies Pro",
    metadata={
        "tier": "pro",
        "features": "unlimited_transcription,priority_support,api_access",
        "max_minutes_per_month": "unlimited",
        "storage_gb": "100",
        "internal_product_code": "TPRO-001"
    }
)

# Invoice metadata
stripe.Invoice.create(
    customer="cus_xxx",
    metadata={
        "billing_period_start": "2025-01-01",
        "billing_period_end": "2025-01-31",
        "usage_minutes": "1250",
        "overage_charges": "0",
        "internal_invoice_id": "INV-2025-001"
    }
)
```

**Searching by Metadata:**

```python
# List customers with specific metadata
customers = stripe.Customer.list(
    limit=100,
    # Note: Cannot filter by metadata in list() - must filter client-side
)

pro_customers = [c for c in customers.auto_paging_iter()
                 if c.metadata.get("plan_tier") == "pro"]
```

**Security Notes:**
- Never store sensitive data (SSN, bank accounts, passwords)
- Metadata is hidden from publishable key requests
- Safe to store internal IDs and non-sensitive attributes

### 6.4 Error Handling

**Common Error Types:**

```python
import stripe

try:
    customer = stripe.Customer.create(email="user@example.com")
except stripe.error.CardError as e:
    # Card declined
    print(f"Card error: {e.user_message}")
except stripe.error.RateLimitError:
    # Too many requests
    print("Rate limit exceeded")
    # Implement exponential backoff
except stripe.error.InvalidRequestError as e:
    # Invalid parameters
    print(f"Invalid request: {e.user_message}")
except stripe.error.AuthenticationError:
    # Invalid API key
    print("Authentication failed - check API key")
except stripe.error.APIConnectionError:
    # Network error
    print("Network error - retry with same idempotency key")
except stripe.error.StripeError as e:
    # Generic Stripe error
    print(f"Stripe error: {e.user_message}")
except Exception as e:
    # Non-Stripe error
    print(f"Unexpected error: {str(e)}")
```

**Exponential Backoff:**

```python
import time
import random

def call_stripe_with_retry(func, max_retries=3, *args, **kwargs):
    """
    Call Stripe API with exponential backoff retry logic.
    """
    for attempt in range(max_retries):
        try:
            return func(*args, **kwargs)
        except stripe.error.RateLimitError:
            if attempt < max_retries - 1:
                wait_time = (2 ** attempt) + random.uniform(0, 1)  # Jitter
                print(f"Rate limited. Retrying in {wait_time:.2f}s...")
                time.sleep(wait_time)
                continue
            raise
        except stripe.error.APIConnectionError:
            if attempt < max_retries - 1:
                wait_time = (2 ** attempt) + random.uniform(0, 1)
                print(f"Network error. Retrying in {wait_time:.2f}s...")
                time.sleep(wait_time)
                continue
            raise
```

### 6.5 Versioning

Stripe uses API versioning to roll out changes safely.

**Setting API Version:**

```python
# Set version for entire account
stripe.api_version = "2024-12-18.acacia"

# Or per-request
customer = stripe.Customer.create(
    email="user@example.com",
    stripe_version="2024-12-18.acacia"
)
```

**Webhook Versioning:**

```python
# Set version when creating webhook
webhook = stripe.WebhookEndpoint.create(
    url="https://api.talkies.app/webhooks/stripe",
    enabled_events=["*"],
    api_version="2024-12-18.acacia"  # Locks webhook to this version
)
```

**Best Practice:** Pin your webhook endpoints to a specific version and upgrade them explicitly when ready.

### 6.6 Rate Limiting

Stripe rate limits API requests to ensure system stability.

**Default Limits:**
- Test mode: 25 requests/second per key
- Live mode: 100 requests/second per key

**Best Practices:**
1. Implement exponential backoff with jitter
2. Batch operations where possible
3. Cache Stripe data locally
4. Use webhooks instead of polling

**Respect Rate Limits:**

```python
import stripe
import time

class StripeRateLimiter:
    def __init__(self, calls_per_second=10):
        self.calls_per_second = calls_per_second
        self.last_call = 0

    def wait_if_needed(self):
        elapsed = time.time() - self.last_call
        min_interval = 1.0 / self.calls_per_second

        if elapsed < min_interval:
            time.sleep(min_interval - elapsed)

        self.last_call = time.time()

# Usage
limiter = StripeRateLimiter(calls_per_second=10)

for email in customer_emails:
    limiter.wait_if_needed()
    customer = stripe.Customer.create(email=email)
```

---

## 7. Complete Provisioning Script

Here's a complete Python script that provisions Stripe for the Talkies SaaS platform:

```python
#!/usr/bin/env python3
"""
Stripe Provisioning Script for Talkies SaaS Platform

This script programmatically configures Stripe with:
- Products & Prices (Free, Pro, Enterprise tiers)
- Customer Portal Configuration
- Webhook Endpoints
- Tax Settings
- Promotion Codes

Usage:
    python provision_stripe.py --mode test
    python provision_stripe.py --mode live --confirm
"""

import os
import sys
import argparse
import uuid
import json
from datetime import datetime, timedelta
from typing import Dict, List, Any

import stripe


class TalkiesStripeProvisioner:
    """Provisions Stripe resources for Talkies SaaS platform."""

    def __init__(self, mode: str = "test"):
        """
        Initialize provisioner.

        Args:
            mode: "test" or "live"
        """
        self.mode = mode
        self.resources = {}

        # Set API key
        if mode == "live":
            stripe.api_key = os.getenv("STRIPE_LIVE_SECRET_KEY")
            self.webhook_url = "https://api.talkies.app/webhooks/stripe"
        else:
            stripe.api_key = os.getenv("STRIPE_TEST_SECRET_KEY")
            self.webhook_url = "https://api.talkies.app/webhooks/stripe-test"

        if not stripe.api_key:
            raise ValueError(f"Stripe API key not found for {mode} mode")

        print(f"\n{'='*60}")
        print(f"Talkies Stripe Provisioner - {mode.upper()} Mode")
        print(f"{'='*60}\n")

    def create_products(self) -> Dict[str, Any]:
        """Create Talkies products."""
        print("Creating products...")

        products = {}

        # Pro Plan
        products["pro"] = stripe.Product.create(
            name="Talkies Pro",
            description="Full access to Talkies voice transcription with unlimited minutes, cloud storage, and priority support",
            metadata={
                "tier": "pro",
                "features": "unlimited_transcription,cloud_storage,priority_support,export_formats",
                "max_minutes": "unlimited",
                "storage_gb": "100"
            },
            idempotency_key=f"product_pro_{self.mode}_{uuid.uuid4()}"
        )
        print(f"  ✓ Created Pro product: {products['pro'].id}")

        # Enterprise Plan
        products["enterprise"] = stripe.Product.create(
            name="Talkies Enterprise",
            description="Enterprise-grade transcription with dedicated support, custom integrations, and advanced features",
            metadata={
                "tier": "enterprise",
                "features": "unlimited_transcription,unlimited_storage,dedicated_support,api_access,custom_integration,sla",
                "max_minutes": "unlimited",
                "storage_gb": "unlimited"
            },
            idempotency_key=f"product_enterprise_{self.mode}_{uuid.uuid4()}"
        )
        print(f"  ✓ Created Enterprise product: {products['enterprise'].id}")

        # Add-on: Extra Storage
        products["storage"] = stripe.Product.create(
            name="Extra Storage",
            description="Additional cloud storage for your transcriptions",
            metadata={
                "type": "addon",
                "unit": "50gb"
            },
            idempotency_key=f"product_storage_{self.mode}_{uuid.uuid4()}"
        )
        print(f"  ✓ Created Storage add-on: {products['storage'].id}")

        self.resources["products"] = products
        return products

    def create_prices(self, products: Dict[str, Any]) -> Dict[str, Any]:
        """Create prices for all products."""
        print("\nCreating prices...")

        prices = {}

        # Pro - Monthly
        prices["pro_monthly"] = stripe.Price.create(
            product=products["pro"].id,
            currency="usd",
            unit_amount=1999,  # $19.99/month
            recurring={
                "interval": "month",
                "interval_count": 1,
                "trial_period_days": 14
            },
            lookup_key="talkies_pro_monthly",
            tax_behavior="exclusive",
            metadata={
                "plan_name": "Pro Monthly",
                "billing_cycle": "monthly",
                "display_price": "$19.99/mo"
            },
            idempotency_key=f"price_pro_monthly_{self.mode}_{uuid.uuid4()}"
        )
        print(f"  ✓ Created Pro Monthly: {prices['pro_monthly'].id} ($19.99/mo)")

        # Pro - Annual (17% discount)
        prices["pro_annual"] = stripe.Price.create(
            product=products["pro"].id,
            currency="usd",
            unit_amount=19900,  # $199/year
            recurring={
                "interval": "year",
                "interval_count": 1,
                "trial_period_days": 14
            },
            lookup_key="talkies_pro_annual",
            tax_behavior="exclusive",
            metadata={
                "plan_name": "Pro Annual",
                "billing_cycle": "annual",
                "display_price": "$199/yr",
                "savings": "$39.88/yr"
            },
            idempotency_key=f"price_pro_annual_{self.mode}_{uuid.uuid4()}"
        )
        print(f"  ✓ Created Pro Annual: {prices['pro_annual'].id} ($199/yr)")

        # Enterprise - Monthly (contact sales, but set a price)
        prices["enterprise_monthly"] = stripe.Price.create(
            product=products["enterprise"].id,
            currency="usd",
            unit_amount=9900,  # $99/month
            recurring={
                "interval": "month",
                "interval_count": 1
            },
            lookup_key="talkies_enterprise_monthly",
            tax_behavior="exclusive",
            metadata={
                "plan_name": "Enterprise Monthly",
                "billing_cycle": "monthly",
                "display_price": "Contact Sales",
                "requires_approval": "true"
            },
            idempotency_key=f"price_enterprise_monthly_{self.mode}_{uuid.uuid4()}"
        )
        print(f"  ✓ Created Enterprise Monthly: {prices['enterprise_monthly'].id} ($99/mo)")

        # Storage Add-on - Monthly
        prices["storage_addon"] = stripe.Price.create(
            product=products["storage"].id,
            currency="usd",
            unit_amount=999,  # $9.99/month per 50GB
            recurring={
                "interval": "month",
                "interval_count": 1
            },
            lookup_key="talkies_storage_addon",
            tax_behavior="exclusive",
            metadata={
                "addon_type": "storage",
                "storage_amount": "50gb",
                "display_price": "$9.99/mo per 50GB"
            },
            idempotency_key=f"price_storage_{self.mode}_{uuid.uuid4()}"
        )
        print(f"  ✓ Created Storage Add-on: {prices['storage_addon'].id} ($9.99/mo)")

        self.resources["prices"] = prices
        return prices

    def create_portal_configuration(self, products: Dict[str, Any], prices: Dict[str, Any]) -> Any:
        """Create customer portal configuration."""
        print("\nCreating customer portal configuration...")

        config = stripe.billing_portal.Configuration.create(
            business_profile={
                "headline": "Manage your Talkies subscription",
                "privacy_policy_url": "https://talkies.app/privacy",
                "terms_of_service_url": "https://talkies.app/terms"
            },
            features={
                "customer_update": {
                    "enabled": True,
                    "allowed_updates": ["email", "address", "phone", "tax_id"]
                },
                "invoice_history": {
                    "enabled": True
                },
                "payment_method_update": {
                    "enabled": True
                },
                "subscription_cancel": {
                    "enabled": True,
                    "mode": "at_period_end",
                    "cancellation_reason": {
                        "enabled": True,
                        "options": [
                            "too_expensive",
                            "missing_features",
                            "switched_service",
                            "unused",
                            "customer_service",
                            "too_complex",
                            "low_quality",
                            "other"
                        ]
                    }
                },
                "subscription_pause": {
                    "enabled": False
                },
                "subscription_update": {
                    "enabled": True,
                    "default_allowed_updates": ["price"],
                    "products": [
                        {
                            "product": products["pro"].id,
                            "prices": [
                                prices["pro_monthly"].id,
                                prices["pro_annual"].id
                            ]
                        }
                    ],
                    "proration_behavior": "always_invoice"
                }
            },
            default_return_url="https://talkies.app/dashboard",
            metadata={
                "config_version": "1.0",
                "environment": self.mode,
                "created_at": datetime.now().isoformat()
            }
        )

        print(f"  ✓ Created portal configuration: {config.id}")
        self.resources["portal_config"] = config
        return config

    def create_webhook_endpoint(self) -> Any:
        """Create webhook endpoint."""
        print("\nCreating webhook endpoint...")

        webhook = stripe.WebhookEndpoint.create(
            url=self.webhook_url,
            enabled_events=[
                # Subscription lifecycle
                "customer.subscription.created",
                "customer.subscription.updated",
                "customer.subscription.deleted",
                "customer.subscription.trial_will_end",

                # Payment events
                "invoice.created",
                "invoice.finalized",
                "invoice.paid",
                "invoice.payment_failed",
                "invoice.payment_action_required",
                "charge.succeeded",
                "charge.failed",
                "charge.refunded",

                # Customer events
                "customer.created",
                "customer.updated",
                "customer.deleted",

                # Payment method events
                "payment_method.attached",
                "payment_method.detached",
                "payment_method.updated",

                # Checkout events
                "checkout.session.completed",
                "checkout.session.expired"
            ],
            api_version="2024-12-18.acacia",
            description=f"Talkies {self.mode} webhook",
            metadata={
                "environment": self.mode,
                "service": "talkies-api",
                "created_at": datetime.now().isoformat()
            }
        )

        print(f"  ✓ Created webhook: {webhook.id}")
        print(f"    URL: {webhook.url}")
        print(f"    Secret: {webhook.secret}")
        print(f"    ⚠️  SAVE THE SECRET TO YOUR ENVIRONMENT VARIABLES!")

        self.resources["webhook"] = webhook
        return webhook

    def configure_tax_settings(self) -> Any:
        """Configure Stripe Tax settings."""
        print("\nConfiguring tax settings...")

        try:
            tax_settings = stripe.tax.Settings.retrieve()

            if tax_settings.status != "active":
                tax_settings = stripe.tax.Settings.update(
                    defaults={
                        "tax_behavior": "exclusive",
                        "tax_code": "txcd_10000000"  # SaaS
                    }
                )
                print(f"  ✓ Activated Stripe Tax")
            else:
                print(f"  ✓ Stripe Tax already active")

            self.resources["tax_settings"] = tax_settings
            return tax_settings
        except stripe.error.InvalidRequestError as e:
            print(f"  ⚠️  Could not configure Stripe Tax: {e.user_message}")
            print(f"     You may need to enable it manually in the Dashboard")
            return None

    def create_promotion_codes(self) -> Dict[str, Any]:
        """Create promotional codes."""
        print("\nCreating promotion codes...")

        promo_codes = {}

        # Launch discount: 20% off first month
        coupon_launch = stripe.Coupon.create(
            percent_off=20,
            duration="once",
            name="Launch Discount - 20% Off",
            metadata={"campaign": "launch_2025"},
            idempotency_key=f"coupon_launch_{self.mode}_{uuid.uuid4()}"
        )

        promo_codes["launch"] = stripe.PromotionCode.create(
            coupon=coupon_launch.id,
            code="TALKIES20",
            metadata={
                "campaign": "launch_2025",
                "description": "20% off first payment"
            }
        )
        print(f"  ✓ Created promo code: TALKIES20 (20% off first payment)")

        # Annual discount: 30% off annual plans
        coupon_annual = stripe.Coupon.create(
            percent_off=30,
            duration="once",
            name="Annual Plan Discount - 30% Off",
            metadata={"campaign": "annual_2025"},
            idempotency_key=f"coupon_annual_{self.mode}_{uuid.uuid4()}"
        )

        promo_codes["annual"] = stripe.PromotionCode.create(
            coupon=coupon_annual.id,
            code="ANNUAL30",
            metadata={
                "campaign": "annual_2025",
                "description": "30% off annual plans"
            }
        )
        print(f"  ✓ Created promo code: ANNUAL30 (30% off annual)")

        # Free trial extension: 30 days instead of 14
        coupon_trial = stripe.Coupon.create(
            duration="once",
            amount_off=0,  # No discount, just for tracking
            currency="usd",
            name="Extended Trial - 30 Days",
            metadata={"campaign": "trial_extension"},
            idempotency_key=f"coupon_trial_{self.mode}_{uuid.uuid4()}"
        )

        promo_codes["trial"] = stripe.PromotionCode.create(
            coupon=coupon_trial.id,
            code="TRIAL30",
            metadata={
                "campaign": "trial_extension",
                "description": "Extended 30-day trial",
                "trial_days": "30"
            }
        )
        print(f"  ✓ Created promo code: TRIAL30 (30-day trial)")

        self.resources["promo_codes"] = promo_codes
        return promo_codes

    def save_configuration(self):
        """Save provisioned resource IDs to JSON file."""
        output_file = f"stripe_config_{self.mode}.json"

        config = {
            "mode": self.mode,
            "created_at": datetime.now().isoformat(),
            "products": {
                name: product.id
                for name, product in self.resources.get("products", {}).items()
            },
            "prices": {
                name: price.id
                for name, price in self.resources.get("prices", {}).items()
            },
            "portal_config_id": self.resources.get("portal_config", {}).get("id"),
            "webhook": {
                "id": self.resources.get("webhook", {}).get("id"),
                "url": self.resources.get("webhook", {}).get("url"),
                "secret": self.resources.get("webhook", {}).get("secret")
            },
            "promo_codes": {
                name: {
                    "id": code.id,
                    "code": code.code
                }
                for name, code in self.resources.get("promo_codes", {}).items()
            }
        }

        with open(output_file, "w") as f:
            json.dump(config, f, indent=2)

        print(f"\n{'='*60}")
        print(f"✓ Configuration saved to: {output_file}")
        print(f"{'='*60}\n")

    def provision(self):
        """Run full provisioning process."""
        try:
            # Create products
            products = self.create_products()

            # Create prices
            prices = self.create_prices(products)

            # Configure customer portal
            portal_config = self.create_portal_configuration(products, prices)

            # Create webhook endpoint
            webhook = self.create_webhook_endpoint()

            # Configure tax
            tax_settings = self.configure_tax_settings()

            # Create promo codes
            promo_codes = self.create_promotion_codes()

            # Save configuration
            self.save_configuration()

            # Print summary
            self.print_summary()

        except Exception as e:
            print(f"\n❌ Error during provisioning: {str(e)}")
            sys.exit(1)

    def print_summary(self):
        """Print provisioning summary."""
        print("\n" + "="*60)
        print("PROVISIONING COMPLETE")
        print("="*60)

        print("\nProducts Created:")
        for name, product in self.resources.get("products", {}).items():
            print(f"  • {name}: {product.id}")

        print("\nPrices Created:")
        for name, price in self.resources.get("prices", {}).items():
            amount = price.unit_amount / 100
            interval = price.recurring.get("interval") if price.recurring else "one-time"
            print(f"  • {name}: {price.id} (${amount:.2f}/{interval})")

        print("\nPortal Configuration:")
        portal = self.resources.get("portal_config")
        if portal:
            print(f"  • ID: {portal.id}")

        print("\nWebhook Endpoint:")
        webhook = self.resources.get("webhook")
        if webhook:
            print(f"  • ID: {webhook.id}")
            print(f"  • URL: {webhook.url}")
            print(f"  • Secret: {webhook.secret[:20]}...")

        print("\nPromotion Codes:")
        for name, code in self.resources.get("promo_codes", {}).items():
            print(f"  • {code.code}: {code.id}")

        print("\n" + "="*60)
        print("Next Steps:")
        print("="*60)
        print("1. Save webhook secret to environment variables:")
        print(f"   STRIPE_{self.mode.upper()}_WEBHOOK_SECRET={webhook.secret}")
        print("\n2. Update your application with the resource IDs")
        print(f"   (see stripe_config_{self.mode}.json)")
        print("\n3. Test the integration:")
        print("   - Create a test checkout session")
        print("   - Complete a test payment")
        print("   - Verify webhook events are received")
        print("\n4. Set up tax registrations in the Stripe Dashboard")
        print("   (if using Stripe Tax)")
        print("="*60 + "\n")


def main():
    parser = argparse.ArgumentParser(
        description="Provision Stripe for Talkies SaaS Platform"
    )
    parser.add_argument(
        "--mode",
        choices=["test", "live"],
        default="test",
        help="Provisioning mode: test or live"
    )
    parser.add_argument(
        "--confirm",
        action="store_true",
        help="Required for live mode provisioning"
    )

    args = parser.parse_args()

    # Safety check for live mode
    if args.mode == "live" and not args.confirm:
        print("❌ Error: Live mode requires --confirm flag")
        print("   Use: python provision_stripe.py --mode live --confirm")
        sys.exit(1)

    if args.mode == "live":
        print("\n⚠️  WARNING: You are about to provision LIVE Stripe resources!")
        print("   This will create real products, prices, and webhooks.")
        response = input("\nType 'yes' to continue: ")
        if response.lower() != "yes":
            print("Provisioning cancelled.")
            sys.exit(0)

    # Run provisioning
    provisioner = TalkiesStripeProvisioner(mode=args.mode)
    provisioner.provision()


if __name__ == "__main__":
    main()
```

### Usage Instructions

**1. Set Environment Variables:**

```bash
# For test mode
export STRIPE_TEST_SECRET_KEY=sk_test_...
export STRIPE_TEST_PUBLISHABLE_KEY=pk_test_...

# For live mode
export STRIPE_LIVE_SECRET_KEY=sk_live_...
export STRIPE_LIVE_PUBLISHABLE_KEY=pk_live_...
```

**2. Install Dependencies:**

```bash
pip install stripe
```

**3. Run Provisioning:**

```bash
# Test mode (safe to run multiple times)
python provision_stripe.py --mode test

# Live mode (requires confirmation)
python provision_stripe.py --mode live --confirm
```

**4. Save Output:**

The script creates `stripe_config_test.json` or `stripe_config_live.json` with all resource IDs.

**5. Update Your Application:**

Use the generated configuration file to reference Stripe resources in your application code.

---

## Additional Resources

### Official Documentation

- [Stripe API Reference](https://docs.stripe.com/api)
- [Stripe Python SDK](https://github.com/stripe/stripe-python)
- [Products & Prices](https://docs.stripe.com/products-prices)
- [Customer Portal](https://docs.stripe.com/customer-management/integrate-customer-portal)
- [Webhooks](https://docs.stripe.com/webhooks)
- [Stripe Tax](https://docs.stripe.com/tax)
- [Testing](https://docs.stripe.com/testing)

### Tools

- [Stripe CLI](https://stripe.com/docs/stripe-cli) - Test webhooks locally
- [Stripe Dashboard](https://dashboard.stripe.com/) - Manage resources
- [API Logs](https://dashboard.stripe.com/logs) - Debug API requests

### Support

- [Stripe Support](https://support.stripe.com/)
- [Community Forum](https://community.stripe.com/)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/stripe-payments)

---

## Conclusion

This document provides comprehensive guidance for programmatically provisioning Stripe for the Talkies SaaS platform. The included Python script automates the entire setup process and follows Stripe best practices for idempotency, error handling, and security.

**Key Takeaways:**

1. Use **lookup keys** for prices to simplify price changes
2. Always use **idempotency keys** for safe retries
3. Configure **Stripe Tax** for automatic tax calculation
4. Set up **webhooks** to handle asynchronous events
5. Store **metadata** to link Stripe objects to your internal systems
6. Test thoroughly in **test mode** before going live
7. Use **environment variables** for API keys and secrets

For questions or issues, refer to the official Stripe documentation or contact Stripe support.

---

**Document Version:** 1.0
**Last Updated:** 2025-01-15
**Author:** Talkies Development Team
**Stripe API Version:** 2024-12-18.acacia
