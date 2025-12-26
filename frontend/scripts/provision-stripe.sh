#!/bin/bash
set -e

# Stripe Provisioning Script for Talkies
# This script sets up Stripe environment variables in Vercel

echo "🔧 Provisioning Stripe environment variables..."

# Public key (can be in all environments)
echo "Setting NEXT_PUBLIC_STRIPE_KEY..."
echo "pk_test_51Se2nwQjUYddJdDkvFJIqppcJuo1PrvVozQQNzBMEq1Q5d0PilUupJMeugf6SoApBM3xTxXxeaTTnmAfAUvkGwD800f2tllyew" | bunx vercel env add NEXT_PUBLIC_STRIPE_KEY production preview development

# Secret key (server-side only)
echo "Setting STRIPE_SECRET_KEY..."
echo "sk_test_51Se2nwQjUYddJdDkZAuCP4PhEpg8O5YvLIB3queynqll8ARiOo6zObyLn7LHR6Fj2wlFtWU7oqpXceGN2WrKAjXJ00zPUWhJglb" | bunx vercel env add STRIPE_SECRET_KEY production preview development

echo "✅ Stripe keys provisioned!"
echo ""
echo "⚠️  Note: STRIPE_WEBHOOK_SECRET needs to be set manually after creating a webhook in Stripe Dashboard"
echo "   1. Go to https://dashboard.stripe.com/test/webhooks"
echo "   2. Create webhook endpoint pointing to: https://your-domain.vercel.app/api/webhook"
echo "   3. Select events: checkout.session.completed, customer.subscription.*"
echo "   4. Copy the webhook signing secret and run:"
echo "   echo 'whsec_xxxxx' | bunx vercel env add STRIPE_WEBHOOK_SECRET production preview development"
