'use client';

import { Card, CardHeader, CardTitle, CardDescription } from '../ui/Card';
import { Globe, Shield, Zap } from 'lucide-react';

const features = [
  {
    icon: Globe,
    title: '100+ Languages',
    description: 'Transcribe in any language with industry-leading accuracy',
    gradient: 'from-purple-500 to-pink-500',
  },
  {
    icon: Shield,
    title: 'Private & Secure',
    description: 'Your audio never leaves your device. Complete privacy guaranteed',
    gradient: 'from-pink-500 to-orange-500',
  },
  {
    icon: Zap,
    title: 'Lightning Fast',
    description: 'Real-time transcription powered by advanced AI technology',
    gradient: 'from-blue-500 to-cyan-500',
  },
];

export function Features() {
  return (
    <section className="py-24 px-6" id="features">
      <div className="max-w-6xl mx-auto">
        <div className="text-center mb-16">
          <h2 className="text-4xl md:text-5xl font-bold mb-4">
            <span className="bg-gradient-to-r from-purple-300 to-pink-300 bg-clip-text text-transparent">
              Everything you need
            </span>
          </h2>
          <p className="text-xl text-neutral-300">
            Professional transcription tools designed for modern workflows
          </p>
        </div>

        <div className="grid md:grid-cols-3 gap-6">
          {features.map((feature, index) => {
            const Icon = feature.icon;
            return (
              <Card
                key={index}
                variant="interactive"
                className="group"
                tabIndex={0}
                role="article"
              >
                <CardHeader>
                  <div
                    className={`w-12 h-12 rounded-xl bg-gradient-to-br ${feature.gradient} flex items-center justify-center mb-4 group-hover:scale-110 transition-transform`}
                    aria-hidden="true"
                  >
                    <Icon className="w-6 h-6 text-white" />
                  </div>
                  <CardTitle>{feature.title}</CardTitle>
                  <CardDescription className="text-base">
                    {feature.description}
                  </CardDescription>
                </CardHeader>
              </Card>
            );
          })}
        </div>
      </div>
    </section>
  );
}
