"use client";

import { Button } from "../ui/Button";
import { Download } from "lucide-react";

export function Hero() {
  return (
    <section className="relative flex min-h-screen items-center justify-center px-6 pt-24 pb-16">
      {/* Animated background orbs */}
      <div
        className="pointer-events-none absolute inset-0 overflow-hidden"
        aria-hidden="true"
      >
        <div className="animate-glow-pulse absolute top-1/4 left-1/4 h-96 w-96 rounded-full bg-purple-600/20 blur-3xl"></div>
        <div
          className="animate-glow-pulse absolute top-1/3 right-1/4 h-96 w-96 rounded-full bg-pink-600/20 blur-3xl"
          style={{ animationDelay: "1s" }}
        ></div>
        <div
          className="animate-glow-pulse absolute bottom-1/4 left-1/3 h-96 w-96 rounded-full bg-blue-600/20 blur-3xl"
          style={{ animationDelay: "2s" }}
        ></div>
      </div>

      <div className="relative mx-auto max-w-4xl text-center">
        <h1 className="mb-6 text-5xl leading-tight font-bold md:text-7xl">
          <span className="animate-gradient bg-gradient-to-r from-purple-300 via-pink-300 to-blue-300 bg-clip-text text-transparent">
            AI-Powered Voice Transcription
          </span>
        </h1>

        <p className="mx-auto mb-12 max-w-2xl text-xl text-neutral-300 md:text-2xl">
          Transform your voice into text with lightning-fast accuracy. Native
          macOS app optimized for Apple Silicon.
        </p>

        <div className="mb-8 flex flex-col items-center justify-center gap-6">
          <Button
            variant="gradient"
            size="lg"
            className="min-w-[250px] gap-2 py-6 text-lg"
          >
            <Download size={24} aria-hidden="true" />
            Download for macOS
          </Button>
          <p className="text-sm text-neutral-500">
            <span className="rounded-full border border-white/10 bg-white/5 px-3 py-1">
              Requires macOS 15+ and Apple Silicon
            </span>
          </p>
        </div>

        <p className="text-sm text-neutral-400">
          Windows & Linux coming soon • No signup required
        </p>
      </div>
    </section>
  );
}
