"use client";

import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
} from "../ui/Card";
import { Button } from "../ui/Button";
import { Check } from "lucide-react";

const plans = [
  {
    name: "Free",
    price: "$0",
    period: "forever",
    description: "Perfect for trying out Talkies",
    features: [
      "Up to 10 minutes/month",
      "5 languages supported",
      "Basic transcription",
      "Export to text",
    ],
    cta: "Get Started",
    variant: "secondary" as const,
    popular: false,
  },
  {
    name: "Pro",
    price: "$10",
    period: "per month",
    description: "For professionals who need more",
    features: [
      "Unlimited transcription",
      "100+ languages",
      "Real-time transcription",
      "Advanced formatting",
      "Priority support",
      "Export to multiple formats",
    ],
    cta: "Start Free Trial",
    variant: "gradient" as const,
    popular: true,
  },
];

export function Pricing() {
  return (
    <section className="px-6 py-24" id="pricing">
      <div className="mx-auto max-w-6xl">
        <div className="mb-16 text-center">
          <h2 className="mb-4 text-4xl font-bold md:text-5xl">
            <span className="bg-gradient-to-r from-purple-300 to-pink-300 bg-clip-text text-transparent">
              Simple, transparent pricing
            </span>
          </h2>
          <p className="text-xl text-neutral-300">
            Choose the plan that works best for you
          </p>
        </div>

        <div className="mx-auto grid max-w-4xl gap-8 md:grid-cols-2">
          {plans.map((plan, index) => (
            <Card
              key={index}
              variant={plan.popular ? "gradient-border" : "default"}
              className="relative"
            >
              {plan.popular && (
                <div className="absolute -top-4 left-1/2 -translate-x-1/2">
                  <span className="rounded-full bg-gradient-to-r from-purple-500 to-pink-500 px-4 py-1 text-sm font-semibold text-white">
                    Most Popular
                  </span>
                </div>
              )}

              <CardHeader>
                <CardTitle className="text-3xl">{plan.name}</CardTitle>
                <div className="mt-4">
                  <span className="bg-gradient-to-r from-purple-300 to-pink-300 bg-clip-text text-5xl font-bold text-transparent">
                    {plan.price}
                  </span>
                  <span className="ml-2 text-neutral-500">/ {plan.period}</span>
                </div>
                <CardDescription className="mt-2 text-base">
                  {plan.description}
                </CardDescription>
              </CardHeader>

              <CardContent className="space-y-6">
                <ul className="space-y-3" role="list">
                  {plan.features.map((feature, featureIndex) => (
                    <li key={featureIndex} className="flex items-start gap-3">
                      <Check
                        className="mt-0.5 h-5 w-5 flex-shrink-0 text-purple-500"
                        aria-hidden="true"
                      />
                      <span className="text-neutral-300">{feature}</span>
                    </li>
                  ))}
                </ul>

                <Button variant={plan.variant} fullWidth size="lg">
                  {plan.cta}
                </Button>
              </CardContent>
            </Card>
          ))}
        </div>

        <p className="mt-8 text-center text-sm text-neutral-500">
          All plans include a 14-day money-back guarantee • Cancel anytime
        </p>
      </div>
    </section>
  );
}
