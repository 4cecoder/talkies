"use client";

import { useState } from "react";
import { X, Shield, Check, Lock, Loader2 } from "lucide-react";
import { PLAN_PRICING } from "../lib/stripe";

interface CheckoutModalProps {
  isOpen: boolean;
  onClose: () => void;
  plan: "free" | "pro";
}

export default function CheckoutModal({
  isOpen,
  onClose,
}: CheckoutModalProps) {
  const [billingCycle, setBillingCycle] = useState<"monthly" | "yearly">(
    "monthly"
  );
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
      const response = await fetch("/api/create-checkout-session", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          priceId,
          billingCycle,
        }),
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.error || "Failed to create checkout session");
      }

      const { url } = await response.json();

      // Redirect to Stripe Checkout
      if (url) {
        window.location.href = url;
      } else {
        throw new Error("No checkout URL returned");
      }
    } catch (err) {
      console.error("Checkout error:", err);
      setError(err instanceof Error ? err.message : "An error occurred");
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center overflow-y-auto p-4">
      {/* Backdrop */}
      <div
        className="fixed inset-0 bg-black/60 backdrop-blur-md"
        onClick={onClose}
      ></div>

      {/* Modal */}
      <div className="relative my-8 w-full max-w-2xl">
        <div className="relative overflow-hidden rounded-3xl">
          {/* Animated gradient border */}
          <div className="animate-gradient absolute inset-0 bg-gradient-to-br from-purple-600 via-pink-600 to-blue-600"></div>
          <div className="absolute inset-[2px] rounded-3xl bg-[#0a0a0f]"></div>

          {/* Content */}
          <div className="relative p-8">
            <button
              onClick={onClose}
              className="absolute top-4 right-4 z-10 text-neutral-400 transition-colors hover:text-white"
            >
              <X className="h-6 w-6" />
            </button>

            <div className="mb-8">
              <h2 className="mb-2 text-3xl font-bold">
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
              <div className="inline-flex rounded-2xl border border-white/10 bg-white/5 p-1">
                <button
                  onClick={() => setBillingCycle("monthly")}
                  className={`rounded-xl px-6 py-3 font-semibold transition-all ${
                    billingCycle === "monthly"
                      ? "bg-gradient-to-r from-purple-600 to-pink-600 text-white"
                      : "text-neutral-400 hover:text-white"
                  }`}
                >
                  Monthly
                </button>
                <button
                  onClick={() => setBillingCycle("yearly")}
                  className={`relative rounded-xl px-6 py-3 font-semibold transition-all ${
                    billingCycle === "yearly"
                      ? "bg-gradient-to-r from-purple-600 to-pink-600 text-white"
                      : "text-neutral-400 hover:text-white"
                  }`}
                >
                  Yearly
                  <span className="absolute -top-2 -right-2 rounded-full bg-gradient-to-r from-yellow-400 to-orange-400 px-2 py-0.5 text-xs font-bold text-black">
                    Save 20%
                  </span>
                </button>
              </div>
            </div>

            {/* Order Summary */}
            <div className="mb-8 rounded-2xl border border-white/10 bg-white/5 p-6 backdrop-blur-xl">
              <h3 className="mb-4 text-lg font-bold text-white">
                Order Summary
              </h3>
              <div className="space-y-3">
                <div className="flex justify-between text-neutral-300">
                  <span>
                    Talkies Pro (
                    {billingCycle === "monthly" ? "Monthly" : "Annual"})
                  </span>
                  <span className="font-semibold text-white">
                    $
                    {billingCycle === "monthly"
                      ? pricing.monthly
                      : pricing.yearly * 12}
                    {billingCycle === "monthly" ? "/mo" : "/yr"}
                  </span>
                </div>
                {billingCycle === "yearly" && (
                  <div className="flex justify-between text-sm text-green-400">
                    <span>Annual discount (20%)</span>
                    <span>-$24</span>
                  </div>
                )}
                <div className="flex justify-between border-t border-white/10 pt-3 text-lg font-bold">
                  <span>Total</span>
                  <span className="bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text text-transparent">
                    $
                    {billingCycle === "monthly"
                      ? pricing.monthly
                      : pricing.yearly * 12}
                    {billingCycle === "monthly" ? "/mo" : "/yr"}
                  </span>
                </div>
              </div>
            </div>

            {/* Error Message */}
            {error && (
              <div className="mb-6 rounded-xl border border-red-500/20 bg-red-500/10 p-4 text-sm text-red-400">
                {error}
              </div>
            )}

            {/* Checkout Button */}
            <form onSubmit={handleCheckout} className="space-y-4">
              <button
                type="submit"
                disabled={loading}
                className="group relative w-full overflow-hidden rounded-xl py-4 font-bold transition-all hover:scale-105 hover:shadow-2xl hover:shadow-purple-500/50 disabled:cursor-not-allowed disabled:opacity-50 disabled:hover:scale-100"
              >
                <div className="animate-gradient-fast absolute inset-0 bg-gradient-to-r from-purple-600 via-pink-600 to-blue-600"></div>
                <span className="relative flex items-center justify-center gap-2 text-white">
                  {loading ? (
                    <>
                      <Loader2 className="h-5 w-5 animate-spin" />
                      Redirecting to Stripe...
                    </>
                  ) : (
                    <>
                      <Lock className="h-5 w-5" />
                      Continue to Checkout
                    </>
                  )}
                </span>
              </button>

              <p className="mt-4 text-center text-xs text-neutral-500">
                Secured by Stripe • Cancel anytime • Money-back guarantee
              </p>
            </form>

            {/* Trust Badges */}
            <div className="mt-6 border-t border-white/10 pt-6">
              <div className="flex items-center justify-center gap-6 text-sm text-neutral-500">
                <div className="flex items-center gap-2">
                  <Shield className="h-4 w-4 text-green-400" />
                  Secure Payment
                </div>
                <div className="flex items-center gap-2">
                  <Check className="h-4 w-4 text-green-400" />
                  Money-back Guarantee
                </div>
                <div className="flex items-center gap-2">
                  <Check className="h-4 w-4 text-green-400" />
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
