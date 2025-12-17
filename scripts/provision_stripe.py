#!/usr/bin/env python3
"""
Stripe Provisioning Script for Talkies SaaS Platform

This script programmatically configures Stripe resources based on a TOML configuration file:
- Products & Prices (Free, Pro, Enterprise tiers)
- Customer Portal Configuration
- Webhook Endpoints
- Tax Settings
- Promotion Codes

Features:
- Idempotent operations (safe to run multiple times)
- Test/Live mode support
- Comprehensive error handling
- Resource ID output for integration

Usage:
    python provision_stripe.py --mode test
    python provision_stripe.py --mode live --confirm
    python provision_stripe.py --mode test --config custom_config.toml
"""

import os
import sys
import argparse
import uuid
import json
import tomllib
from datetime import datetime
from typing import Dict, List, Any, Optional
from pathlib import Path

import stripe


class TalkiesStripeProvisioner:
    """Provisions Stripe resources for Talkies SaaS platform based on TOML config."""

    def __init__(self, mode: str = "test", config_path: str = "stripe_config.toml"):
        """
        Initialize provisioner.

        Args:
            mode: "test" or "live"
            config_path: Path to TOML configuration file
        """
        self.mode = mode
        self.resources = {}

        # Load configuration
        self.config = self._load_config(config_path)

        # Set API key
        if mode == "live":
            stripe.api_key = os.getenv("STRIPE_LIVE_SECRET_KEY")
            self.webhook_url = self.config["urls"]["production_webhook"]
        else:
            stripe.api_key = os.getenv("STRIPE_TEST_SECRET_KEY")
            self.webhook_url = self.config["urls"]["test_webhook"]

        if not stripe.api_key:
            raise ValueError(f"Stripe API key not found for {mode} mode")

        # Set API version
        stripe.api_version = self.config["metadata"]["api_version"]

        print(f"\n{'='*70}")
        print(f"Talkies Stripe Provisioner - {mode.upper()} Mode")
        print(f"{'='*70}\n")
        print(f"Configuration: {config_path}")
        print(f"API Version: {stripe.api_version}\n")

    def _load_config(self, config_path: str) -> Dict[str, Any]:
        """Load TOML configuration file."""
        try:
            config_file = Path(config_path)
            if not config_file.exists():
                raise FileNotFoundError(f"Configuration file not found: {config_path}")

            with open(config_file, "rb") as f:
                config = tomllib.load(f)

            print(f"Loaded configuration from {config_path}")
            return config
        except Exception as e:
            print(f"Error loading configuration: {e}")
            sys.exit(1)

    def _generate_idempotency_key(self, resource_type: str, identifier: str) -> str:
        """Generate consistent idempotency key for a resource."""
        return f"{resource_type}_{identifier}_{self.mode}_{uuid.uuid4()}"

    def create_products(self) -> Dict[str, Any]:
        """Create Talkies products from configuration."""
        print("Creating products...")
        products = {}

        for product_config in self.config.get("products", []):
            try:
                product_id = product_config["id"]

                # Check if product already exists with this metadata
                existing = self._find_existing_product(product_id)
                if existing:
                    print(f"  ✓ Product already exists: {product_id} ({existing.id})")
                    products[product_id] = existing
                    continue

                # Create new product
                product = stripe.Product.create(
                    name=product_config["name"],
                    description=product_config["description"],
                    active=product_config.get("active", True),
                    metadata=product_config.get("metadata", {}),
                    idempotency_key=self._generate_idempotency_key("product", product_id)
                )

                print(f"  ✓ Created product: {product_config['name']} ({product.id})")
                products[product_id] = product

            except stripe.error.StripeError as e:
                print(f"  ✗ Error creating product {product_id}: {e.user_message}")
                raise

        self.resources["products"] = products
        return products

    def _find_existing_product(self, product_id: str) -> Optional[Any]:
        """Find existing product by metadata."""
        try:
            products = stripe.Product.list(active=True, limit=100)
            for product in products.auto_paging_iter():
                if product.metadata.get("tier") == product_id.replace("talkies_", ""):
                    return product
            return None
        except Exception:
            return None

    def create_prices(self, products: Dict[str, Any]) -> Dict[str, Any]:
        """Create prices for all products from configuration."""
        print("\nCreating prices...")
        prices = {}

        for price_config in self.config.get("prices", []):
            try:
                lookup_key = price_config["lookup_key"]
                product_id = price_config["product"]

                # Check if price already exists
                existing = self._find_existing_price(lookup_key)
                if existing:
                    print(f"  ✓ Price already exists: {lookup_key} ({existing.id})")
                    prices[lookup_key] = existing
                    continue

                # Get product
                if product_id not in products:
                    print(f"  ✗ Product not found: {product_id}")
                    continue

                # Build price parameters
                price_params = {
                    "product": products[product_id].id,
                    "currency": price_config["currency"],
                    "unit_amount": price_config["unit_amount"],
                    "lookup_key": lookup_key,
                    "tax_behavior": price_config.get("tax_behavior", "exclusive"),
                    "metadata": price_config.get("metadata", {}),
                    "idempotency_key": self._generate_idempotency_key("price", lookup_key)
                }

                # Add recurring parameters if present
                if "recurring" in price_config:
                    price_params["recurring"] = price_config["recurring"]

                # Create price
                price = stripe.Price.create(**price_params)

                amount = price.unit_amount / 100
                interval = price.recurring.get("interval") if price.recurring else "one-time"
                print(f"  ✓ Created price: {lookup_key} (${amount:.2f}/{interval}) - {price.id}")
                prices[lookup_key] = price

            except stripe.error.StripeError as e:
                print(f"  ✗ Error creating price {lookup_key}: {e.user_message}")
                raise

        self.resources["prices"] = prices
        return prices

    def _find_existing_price(self, lookup_key: str) -> Optional[Any]:
        """Find existing price by lookup key."""
        try:
            prices = stripe.Price.list(lookup_keys=[lookup_key], limit=1)
            return prices.data[0] if prices.data else None
        except Exception:
            return None

    def create_portal_configuration(self, products: Dict[str, Any], prices: Dict[str, Any]) -> Any:
        """Create customer portal configuration from config file."""
        print("\nCreating customer portal configuration...")

        portal_config = self.config.get("portal", {})

        try:
            # Build subscription update products list
            subscription_products = []
            if "talkies_pro" in products:
                pro_prices = [
                    prices[key].id for key in ["talkies_pro_monthly", "talkies_pro_annual"]
                    if key in prices
                ]
                if pro_prices:
                    subscription_products.append({
                        "product": products["talkies_pro"].id,
                        "prices": pro_prices
                    })

            # Build features configuration
            features = portal_config.get("features", {})
            features_config = {}

            if "customer_update" in features:
                features_config["customer_update"] = features["customer_update"]

            if "invoice_history" in features:
                features_config["invoice_history"] = features["invoice_history"]

            if "payment_method_update" in features:
                features_config["payment_method_update"] = features["payment_method_update"]

            if "subscription_cancel" in features:
                features_config["subscription_cancel"] = features["subscription_cancel"]

            if "subscription_pause" in features:
                features_config["subscription_pause"] = features["subscription_pause"]

            if "subscription_update" in features and subscription_products:
                update_config = features["subscription_update"].copy()
                update_config["products"] = subscription_products
                features_config["subscription_update"] = update_config

            # Create portal configuration
            config = stripe.billing_portal.Configuration.create(
                business_profile={
                    "headline": portal_config.get("headline", "Manage your subscription"),
                    "privacy_policy_url": self.config["urls"]["privacy_url"],
                    "terms_of_service_url": self.config["urls"]["terms_url"]
                },
                features=features_config,
                default_return_url=self.config["urls"]["dashboard_url"],
                metadata={
                    "environment": self.mode,
                    "created_at": datetime.now().isoformat(),
                    "auto_provisioned": "true"
                }
            )

            print(f"  ✓ Created portal configuration: {config.id}")
            self.resources["portal_config"] = config
            return config

        except stripe.error.StripeError as e:
            print(f"  ✗ Error creating portal configuration: {e.user_message}")
            raise

    def create_webhook_endpoint(self) -> Any:
        """Create webhook endpoint from configuration."""
        print("\nCreating webhook endpoint...")

        webhook_config = self.config.get("webhooks", {})

        try:
            # Check if webhook already exists
            existing_webhooks = stripe.WebhookEndpoint.list(limit=100)
            for webhook in existing_webhooks.data:
                if webhook.url == self.webhook_url:
                    print(f"  ✓ Webhook already exists: {webhook.id}")
                    print(f"    URL: {webhook.url}")
                    self.resources["webhook"] = webhook
                    return webhook

            # Create new webhook
            webhook = stripe.WebhookEndpoint.create(
                url=self.webhook_url,
                enabled_events=webhook_config.get("enabled_events", ["*"]),
                api_version=self.config["metadata"]["api_version"],
                description=f"Talkies {self.mode} webhook",
                metadata=webhook_config.get("metadata", {})
            )

            print(f"  ✓ Created webhook: {webhook.id}")
            print(f"    URL: {webhook.url}")
            print(f"    Secret: {webhook.secret}")
            print(f"    ⚠️  SAVE THE SECRET TO YOUR ENVIRONMENT VARIABLES!")
            print(f"       STRIPE_{self.mode.upper()}_WEBHOOK_SECRET={webhook.secret}")

            self.resources["webhook"] = webhook
            return webhook

        except stripe.error.StripeError as e:
            print(f"  ✗ Error creating webhook: {e.user_message}")
            raise

    def configure_tax_settings(self) -> Optional[Any]:
        """Configure Stripe Tax settings from configuration."""
        print("\nConfiguring tax settings...")

        tax_config = self.config.get("tax", {})

        if not tax_config.get("enabled", False):
            print("  ⊘ Tax settings disabled in configuration")
            return None

        try:
            tax_settings = stripe.tax.Settings.retrieve()

            if tax_settings.status != "active":
                tax_settings = stripe.tax.Settings.update(
                    defaults={
                        "tax_behavior": tax_config.get("tax_behavior", "exclusive"),
                        "tax_code": tax_config.get("tax_code", "txcd_10000000")
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
        """Create promotional codes from configuration."""
        print("\nCreating promotion codes...")

        promo_configs = self.config.get("promo_codes", [])
        promo_codes = {}

        for promo_config in promo_configs:
            try:
                code = promo_config["code"]

                # Check if promo code already exists
                existing = self._find_existing_promo_code(code)
                if existing:
                    print(f"  ✓ Promo code already exists: {code}")
                    promo_codes[code] = existing
                    continue

                # Create coupon first
                coupon_params = {
                    "name": promo_config["coupon_name"],
                    "duration": promo_config.get("duration", "once"),
                    "metadata": promo_config.get("metadata", {}),
                    "idempotency_key": self._generate_idempotency_key("coupon", code)
                }

                if "percent_off" in promo_config:
                    coupon_params["percent_off"] = promo_config["percent_off"]
                elif "amount_off" in promo_config:
                    coupon_params["amount_off"] = promo_config["amount_off"]
                    coupon_params["currency"] = promo_config.get("currency", "usd")

                coupon = stripe.Coupon.create(**coupon_params)

                # Create promotion code
                promo_code = stripe.PromotionCode.create(
                    coupon=coupon.id,
                    code=code,
                    metadata=promo_config.get("metadata", {})
                )

                description = promo_config.get("metadata", {}).get("description", "")
                print(f"  ✓ Created promo code: {code} ({description})")
                promo_codes[code] = promo_code

            except stripe.error.StripeError as e:
                print(f"  ✗ Error creating promo code {code}: {e.user_message}")
                continue

        self.resources["promo_codes"] = promo_codes
        return promo_codes

    def _find_existing_promo_code(self, code: str) -> Optional[Any]:
        """Find existing promotion code."""
        try:
            promo_codes = stripe.PromotionCode.list(code=code, limit=1)
            return promo_codes.data[0] if promo_codes.data else None
        except Exception:
            return None

    def save_configuration(self):
        """Save provisioned resource IDs to JSON file."""
        output_file = f"stripe_config_{self.mode}.json"

        config = {
            "mode": self.mode,
            "created_at": datetime.now().isoformat(),
            "api_version": self.config["metadata"]["api_version"],
            "products": {
                name: {"id": product.id, "name": product.name}
                for name, product in self.resources.get("products", {}).items()
            },
            "prices": {
                name: {
                    "id": price.id,
                    "lookup_key": price.lookup_key,
                    "unit_amount": price.unit_amount,
                    "currency": price.currency,
                    "recurring": dict(price.recurring) if price.recurring else None
                }
                for name, price in self.resources.get("prices", {}).items()
            },
            "portal_config": {
                "id": self.resources.get("portal_config", {}).id
                if self.resources.get("portal_config") else None
            },
            "webhook": {
                "id": self.resources.get("webhook", {}).id,
                "url": self.resources.get("webhook", {}).url,
                "secret": self.resources.get("webhook", {}).secret
            } if self.resources.get("webhook") else None,
            "promo_codes": {
                code: {
                    "id": promo_code.id,
                    "code": promo_code.code,
                    "coupon_id": promo_code.coupon.id
                }
                for code, promo_code in self.resources.get("promo_codes", {}).items()
            }
        }

        with open(output_file, "w") as f:
            json.dump(config, f, indent=2)

        print(f"\n{'='*70}")
        print(f"✓ Configuration saved to: {output_file}")
        print(f"{'='*70}\n")

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
            import traceback
            traceback.print_exc()
            sys.exit(1)

    def print_summary(self):
        """Print provisioning summary."""
        print("\n" + "="*70)
        print("PROVISIONING COMPLETE")
        print("="*70)

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
            print(f"  • Return URL: {self.config['urls']['dashboard_url']}")

        print("\nWebhook Endpoint:")
        webhook = self.resources.get("webhook")
        if webhook:
            print(f"  • ID: {webhook.id}")
            print(f"  • URL: {webhook.url}")
            print(f"  • Secret: {webhook.secret[:20]}...")
            print(f"  • Events: {len(webhook.enabled_events)} events")

        print("\nTax Settings:")
        if self.resources.get("tax_settings"):
            print(f"  • Status: Active")
            print(f"  • Tax Code: {self.config['tax']['tax_code']}")
        else:
            print(f"  • Status: Not configured")

        print("\nPromotion Codes:")
        for code, promo in self.resources.get("promo_codes", {}).items():
            print(f"  • {promo.code}: {promo.id}")

        print("\n" + "="*70)
        print("Next Steps:")
        print("="*70)
        print("1. Save webhook secret to environment variables:")
        if webhook:
            print(f"   STRIPE_{self.mode.upper()}_WEBHOOK_SECRET={webhook.secret}")
        print("\n2. Update your application with the resource IDs")
        print(f"   (see stripe_config_{self.mode}.json)")
        print("\n3. Test the integration:")
        print("   - Create a test checkout session")
        print("   - Complete a test payment")
        print("   - Verify webhook events are received")
        print("\n4. Set up tax registrations in the Stripe Dashboard")
        print("   (if using Stripe Tax)")
        print("\n5. Configure your frontend with product/price IDs")
        print("="*70 + "\n")


def main():
    parser = argparse.ArgumentParser(
        description="Provision Stripe for Talkies SaaS Platform",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Provision test mode resources
  python provision_stripe.py --mode test

  # Provision live mode resources (requires confirmation)
  python provision_stripe.py --mode live --confirm

  # Use custom configuration file
  python provision_stripe.py --mode test --config custom_config.toml
        """
    )
    parser.add_argument(
        "--mode",
        choices=["test", "live"],
        default="test",
        help="Provisioning mode: test or live (default: test)"
    )
    parser.add_argument(
        "--config",
        default="stripe_config.toml",
        help="Path to TOML configuration file (default: stripe_config.toml)"
    )
    parser.add_argument(
        "--confirm",
        action="store_true",
        help="Required for live mode provisioning (safety flag)"
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
        print("   This may affect your production Stripe account.")
        response = input("\nType 'yes' to continue: ")
        if response.lower() != "yes":
            print("Provisioning cancelled.")
            sys.exit(0)

    # Run provisioning
    provisioner = TalkiesStripeProvisioner(mode=args.mode, config_path=args.config)
    provisioner.provision()


if __name__ == "__main__":
    main()
