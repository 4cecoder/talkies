'use client';

import { Card, CardHeader, CardTitle, CardDescription, CardContent } from '../ui/Card';
import { Button } from '../ui/Button';
import { Check } from 'lucide-react';

const plans = [
  {
    name: 'Free',
    price: '$0',
    period: 'forever',
    description: 'Perfect for trying out Talkies',
    features: [
      'Up to 10 minutes/month',
      '5 languages supported',
      'Basic transcription',
      'Export to text',
    ],
    cta: 'Get Started',
    variant: 'secondary' as const,
    popular: false,
  },
  {
    name: 'Pro',
    price: '$10',
    period: 'per month',
    description: 'For professionals who need more',
    features: [
      'Unlimited transcription',
      '100+ languages',
      'Real-time transcription',
      'Advanced formatting',
      'Priority support',
      'Export to multiple formats',
    ],
    cta: 'Start Free Trial',
    variant: 'gradient' as const,
    popular: true,
  },
];

export function Pricing() {
  return (
    <section className="py-24 px-6" id="pricing">
      <div className="max-w-6xl mx-auto">
        <div className="text-center mb-16">
          <h2 className="text-4xl md:text-5xl font-bold mb-4">
            <span className="bg-gradient-to-r from-purple-300 to-pink-300 bg-clip-text text-transparent">
              Simple, transparent pricing
            </span>
          </h2>
          <p className="text-xl text-neutral-300">
            Choose the plan that works best for you
          </p>
        </div>

        <div className="grid md:grid-cols-2 gap-8 max-w-4xl mx-auto">
          {plans.map((plan, index) => (
            <Card
              key={index}
              variant={plan.popular ? 'gradient-border' : 'default'}
              className="relative"
            >
              {plan.popular && (
                <div className="absolute -top-4 left-1/2 -translate-x-1/2">
                  <span className="px-4 py-1 bg-gradient-to-r from-purple-500 to-pink-500 text-white text-sm font-semibold rounded-full">
                    Most Popular
                  </span>
                </div>
              )}

              <CardHeader>
                <CardTitle className="text-3xl">{plan.name}</CardTitle>
                <div className="mt-4">
                  <span className="text-5xl font-bold bg-gradient-to-r from-purple-300 to-pink-300 bg-clip-text text-transparent">
                    {plan.price}
                  </span>
                  <span className="text-neutral-500 ml-2">/ {plan.period}</span>
                </div>
                <CardDescription className="text-base mt-2">
                  {plan.description}
                </CardDescription>
              </CardHeader>

              <CardContent className="space-y-6">
                <ul className="space-y-3" role="list">
                  {plan.features.map((feature, featureIndex) => (
                    <li key={featureIndex} className="flex items-start gap-3">
                      <Check
                        className="w-5 h-5 text-purple-500 flex-shrink-0 mt-0.5"
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

        <p className="text-center text-sm text-neutral-500 mt-8">
          All plans include a 14-day money-back guarantee • Cancel anytime
        </p>
      </div>
    </section>
  );
}
