'use client';

import { useState } from 'react';
import { X, Shield, Check, Lock, Loader2 } from 'lucide-react';
import { PLAN_PRICING } from '../lib/stripe';

interface CheckoutModalProps {
  isOpen: boolean;
  onClose: () => void;
  plan: 'free' | 'pro';
}

export default function CheckoutModal({ isOpen, onClose, plan }: CheckoutModalProps) {
  const [billingCycle, setBillingCycle] = useState<'monthly' | 'yearly'>('monthly');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!isOpen) return null;

  const pricing = {
    monthly: 10,
    yearly: 8, // $96/year = $8/month
  };

  const handleCheckout = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      // Get the price ID based on billing cycle
      const priceId = PLAN_PRICING[billingCycle].priceId;

      // Create checkout session
      const response = await fetch('/api/create-checkout-session', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          priceId,
          billingCycle,
        }),
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.error || 'Failed to create checkout session');
      }

      const { url } = await response.json();

      // Redirect to Stripe Checkout
      if (url) {
        window.location.href = url;
      } else {
        throw new Error('No checkout URL returned');
      }
    } catch (err) {
      console.error('Checkout error:', err);
      setError(err instanceof Error ? err.message : 'An error occurred');
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 overflow-y-auto">
      {/* Backdrop */}
      <div
        className="fixed inset-0 bg-black/60 backdrop-blur-md"
        onClick={onClose}
      ></div>

      {/* Modal */}
      <div className="relative w-full max-w-2xl my-8">
        <div className="relative rounded-3xl overflow-hidden">
          {/* Animated gradient border */}
          <div className="absolute inset-0 bg-gradient-to-br from-purple-600 via-pink-600 to-blue-600 animate-gradient"></div>
          <div className="absolute inset-[2px] rounded-3xl bg-[#0a0a0f]"></div>

          {/* Content */}
          <div className="relative p-8">
            <button
              onClick={onClose}
              className="absolute top-4 right-4 text-neutral-400 hover:text-white transition-colors z-10"
            >
              <X className="w-6 h-6" />
            </button>

            <div className="mb-8">
              <h2 className="text-3xl font-bold mb-2">
                <span className="bg-gradient-to-r from-purple-300 to-pink-300 bg-clip-text text-transparent">
                  Complete Your Purchase
                </span>
              </h2>
              <p className="text-neutral-400">
                Start your Talkies Pro subscription today
              </p>
            </div>

            {/* Billing Cycle Toggle */}
            <div className="mb-8">
              <div className="inline-flex p-1 rounded-2xl bg-white/5 border border-white/10">
                <button
                  onClick={() => setBillingCycle('monthly')}
                  className={`px-6 py-3 rounded-xl font-semibold transition-all ${
                    billingCycle === 'monthly'
                      ? 'bg-gradient-to-r from-purple-600 to-pink-600 text-white'
                      : 'text-neutral-400 hover:text-white'
                  }`}
                >
                  Monthly
                </button>
                <button
                  onClick={() => setBillingCycle('yearly')}
                  className={`px-6 py-3 rounded-xl font-semibold transition-all relative ${
                    billingCycle === 'yearly'
                      ? 'bg-gradient-to-r from-purple-600 to-pink-600 text-white'
                      : 'text-neutral-400 hover:text-white'
                  }`}
                >
                  Yearly
                  <span className="absolute -top-2 -right-2 px-2 py-0.5 bg-gradient-to-r from-yellow-400 to-orange-400 text-black text-xs font-bold rounded-full">
                    Save 20%
                  </span>
                </button>
              </div>
            </div>

            {/* Order Summary */}
            <div className="mb-8 p-6 rounded-2xl backdrop-blur-xl bg-white/5 border border-white/10">
              <h3 className="text-lg font-bold mb-4 text-white">Order Summary</h3>
              <div className="space-y-3">
                <div className="flex justify-between text-neutral-300">
                  <span>Talkies Pro ({billingCycle === 'monthly' ? 'Monthly' : 'Annual'})</span>
                  <span className="font-semibold text-white">
                    ${billingCycle === 'monthly' ? pricing.monthly : pricing.yearly * 12}
                    {billingCycle === 'monthly' ? '/mo' : '/yr'}
                  </span>
                </div>
                {billingCycle === 'yearly' && (
                  <div className="flex justify-between text-sm text-green-400">
                    <span>Annual discount (20%)</span>
                    <span>-$24</span>
                  </div>
                )}
                <div className="pt-3 border-t border-white/10 flex justify-between text-lg font-bold">
                  <span>Total</span>
                  <span className="bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text text-transparent">
                    ${billingCycle === 'monthly' ? pricing.monthly : pricing.yearly * 12}
                    {billingCycle === 'monthly' ? '/mo' : '/yr'}
                  </span>
                </div>
              </div>
            </div>

            {/* Error Message */}
            {error && (
              <div className="mb-6 p-4 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm">
                {error}
              </div>
            )}

            {/* Checkout Button */}
            <form onSubmit={handleCheckout} className="space-y-4">
              <button
                type="submit"
                disabled={loading}
                className="w-full relative py-4 rounded-xl font-bold overflow-hidden group transition-all hover:scale-105 hover:shadow-2xl hover:shadow-purple-500/50 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:scale-100"
              >
                <div className="absolute inset-0 bg-gradient-to-r from-purple-600 via-pink-600 to-blue-600 animate-gradient-fast"></div>
                <span className="relative text-white flex items-center justify-center gap-2">
                  {loading ? (
                    <>
                      <Loader2 className="w-5 h-5 animate-spin" />
                      Redirecting to Stripe...
                    </>
                  ) : (
                    <>
                      <Lock className="w-5 h-5" />
                      Continue to Checkout
                    </>
                  )}
                </span>
              </button>

              <p className="text-center text-xs text-neutral-500 mt-4">
                Secured by Stripe • Cancel anytime • Money-back guarantee
              </p>
            </form>

            {/* Trust Badges */}
            <div className="mt-6 pt-6 border-t border-white/10">
              <div className="flex items-center justify-center gap-6 text-neutral-500 text-sm">
                <div className="flex items-center gap-2">
                  <Shield className="w-4 h-4 text-green-400" />
                  Secure Payment
                </div>
                <div className="flex items-center gap-2">
                  <Check className="w-4 h-4 text-green-400" />
                  Money-back Guarantee
                </div>
                <div className="flex items-center gap-2">
                  <Check className="w-4 h-4 text-green-400" />
                  Cancel Anytime
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
