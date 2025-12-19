import { loadStripe, Stripe } from '@stripe/stripe-js';

// Stripe public key
const stripePublicKey = process.env.NEXT_PUBLIC_STRIPE_KEY;

if (!stripePublicKey) {
  console.warn('NEXT_PUBLIC_STRIPE_KEY is not set');
}

// Singleton Stripe instance
let stripePromise: Promise<Stripe | null>;

export const getStripe = () => {
  if (!stripePromise) {
    stripePromise = loadStripe(stripePublicKey || '');
  }
  return stripePromise;
};

// Price IDs for different plans
export const STRIPE_PRICES = {
  monthly: process.env.NEXT_PUBLIC_STRIPE_MONTHLY_PRICE_ID || 'price_monthly',
  yearly: process.env.NEXT_PUBLIC_STRIPE_YEARLY_PRICE_ID || 'price_yearly',
} as const;

// Plan pricing information
export const PLAN_PRICING = {
  monthly: {
    amount: 10,
    interval: 'month' as const,
    priceId: STRIPE_PRICES.monthly,
  },
  yearly: {
    amount: 96,
    interval: 'year' as const,
    priceId: STRIPE_PRICES.yearly,
  },
} as const;

// Helper to format currency
export const formatCurrency = (amount: number) => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
  }).format(amount);
};
