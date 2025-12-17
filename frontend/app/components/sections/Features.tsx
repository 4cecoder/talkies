"use client";

import { Card, CardHeader, CardTitle, CardDescription } from "../ui/Card";
import { Globe, Shield, Zap } from "lucide-react";

const features = [
  {
    icon: Globe,
    title: "100+ Languages",
    description: "Transcribe in any language with industry-leading accuracy",
    gradient: "from-purple-500 to-pink-500",
  },
  {
    icon: Shield,
    title: "Private & Secure",
    description:
      "Your audio never leaves your device. Complete privacy guaranteed",
    gradient: "from-pink-500 to-orange-500",
  },
  {
    icon: Zap,
    title: "Lightning Fast",
    description: "Real-time transcription powered by advanced AI technology",
    gradient: "from-blue-500 to-cyan-500",
  },
];

export function Features() {
  return (
    <section className="px-6 py-24" id="features">
      <div className="mx-auto max-w-6xl">
        <div className="mb-16 text-center">
          <h2 className="mb-4 text-4xl font-bold md:text-5xl">
            <span className="bg-gradient-to-r from-purple-300 to-pink-300 bg-clip-text text-transparent">
              Everything you need
            </span>
          </h2>
          <p className="text-xl text-neutral-300">
            Professional transcription tools designed for modern workflows
          </p>
        </div>

        <div className="grid gap-6 md:grid-cols-3">
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
                    className={`h-12 w-12 rounded-xl bg-gradient-to-br ${feature.gradient} mb-4 flex items-center justify-center transition-transform group-hover:scale-110`}
                    aria-hidden="true"
                  >
                    <Icon className="h-6 w-6 text-white" />
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
