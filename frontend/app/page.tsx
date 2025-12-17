"use client";

import { useState } from "react";
import AuthModal from "./components/AuthModal";
import CheckoutModal from "./components/CheckoutModal";
import {
  Globe,
  Shield,
  TrendingUp,
  Users,
  Award,
  Zap,
  Check,
  ArrowRight,
  Sparkles,
  Download,
  Star,
} from "lucide-react";

export default function Home() {
  const [authModalOpen, setAuthModalOpen] = useState(false);
  const [checkoutModalOpen, setCheckoutModalOpen] = useState(false);
  const [authMode, setAuthMode] = useState<"login" | "signup">("login");

  return (
    <div className="relative min-h-screen overflow-hidden bg-[#0a0a0f] text-white">
      {/* Animated gradient background orbs */}
      <div className="pointer-events-none fixed inset-0 overflow-hidden">
        <div className="animate-glow absolute top-0 -left-1/4 h-[800px] w-[800px] rounded-full bg-gradient-to-br from-purple-600/30 via-violet-600/20 to-transparent blur-3xl"></div>
        <div
          className="animate-glow absolute top-1/4 -right-1/4 h-[600px] w-[600px] rounded-full bg-gradient-to-bl from-blue-600/30 via-cyan-600/20 to-transparent blur-3xl"
          style={{ animationDelay: "1s" }}
        ></div>
        <div
          className="animate-glow absolute bottom-0 left-1/3 h-[700px] w-[700px] rounded-full bg-gradient-to-tr from-pink-600/25 via-fuchsia-600/15 to-transparent blur-3xl"
          style={{ animationDelay: "2s" }}
        ></div>
      </div>

      {/* Header with glassmorphism */}
      <header className="fixed top-0 z-50 w-full border-b border-white/10 bg-white/5 shadow-lg shadow-purple-500/5 backdrop-blur-xl">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-6 py-4">
          <div className="bg-gradient-to-r from-purple-400 via-pink-400 to-blue-400 bg-clip-text text-xl font-bold text-transparent">
            Talkies
          </div>
          <nav className="hidden items-center gap-8 md:flex">
            <a
              href="#features"
              className="text-neutral-300 transition-all hover:scale-105 hover:text-white"
            >
              Features
            </a>
            <a
              href="#pricing"
              className="text-neutral-300 transition-all hover:scale-105 hover:text-white"
            >
              Pricing
            </a>
            <a
              href="#testimonials"
              className="text-neutral-300 transition-all hover:scale-105 hover:text-white"
            >
              Testimonials
            </a>
            <a
              href="#faq"
              className="text-neutral-300 transition-all hover:scale-105 hover:text-white"
            >
              FAQ
            </a>
            <button
              onClick={() => {
                setAuthMode("login");
                setAuthModalOpen(true);
              }}
              className="rounded-xl border border-white/10 bg-white/5 px-4 py-2 transition-all hover:bg-white/10"
            >
              Sign In
            </button>
            <button
              onClick={() => setCheckoutModalOpen(true)}
              className="group relative overflow-hidden rounded-xl px-6 py-2 font-semibold transition-all hover:scale-105"
            >
              <div className="animate-gradient-fast absolute inset-0 bg-gradient-to-r from-purple-600 to-pink-600"></div>
              <span className="relative text-white">Get Started</span>
            </button>
          </nav>
        </div>
      </header>

      {/* Modals */}
      <AuthModal
        isOpen={authModalOpen}
        onClose={() => setAuthModalOpen(false)}
        initialMode={authMode}
      />
      <CheckoutModal
        isOpen={checkoutModalOpen}
        onClose={() => setCheckoutModalOpen(false)}
        plan="pro"
      />

      {/* Hero Section */}
      <section className="relative px-6 pt-32 pb-20">
        <div className="relative z-10 mx-auto max-w-4xl text-center">
          <div className="mb-4 flex justify-center">
            <div className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-4 py-2 backdrop-blur-xl">
              <Sparkles className="h-4 w-4 text-yellow-400" />
              <span className="text-sm text-neutral-300">
                Voice-Powered AI Writing
              </span>
            </div>
          </div>
          <h1 className="mb-6 text-5xl leading-tight font-bold md:text-7xl">
            <span className="animate-gradient bg-gradient-to-r from-purple-300 via-pink-300 to-blue-300 bg-clip-text text-transparent">
              Write 3x faster,
            </span>
            <br />
            <span className="animate-gradient bg-gradient-to-r from-blue-300 via-cyan-300 to-purple-300 bg-clip-text text-transparent">
              without lifting a finger
            </span>
          </h1>
          <p className="mx-auto mb-12 max-w-2xl text-xl text-neutral-300 md:text-2xl">
            Voice-powered writing assistant that helps you capture ideas
            instantly
          </p>

          {/* Download Button - macOS */}
          <div className="mb-8 flex flex-col items-center justify-center gap-6">
            <button
              onClick={() => setCheckoutModalOpen(true)}
              className="group relative overflow-hidden rounded-full px-10 py-5 font-semibold transition-all hover:scale-105 hover:shadow-2xl hover:shadow-purple-500/50"
            >
              <div className="animate-gradient-fast absolute inset-0 bg-gradient-to-r from-purple-600 via-pink-600 to-blue-600"></div>
              <div className="absolute inset-0 bg-gradient-to-r from-purple-600 via-pink-600 to-blue-600 opacity-0 blur-xl transition-opacity group-hover:opacity-100"></div>
              <span className="relative flex items-center gap-2 text-lg font-bold text-white">
                <Download className="h-6 w-6" />
                Download for macOS
              </span>
            </button>
            <div className="flex items-center gap-2 text-sm text-neutral-500">
              <span className="rounded-full border border-white/10 bg-white/5 px-3 py-1">
                Requires macOS 15+ and Apple Silicon
              </span>
            </div>
          </div>

          <div className="text-sm text-neutral-400">
            Windows & Linux coming soon • No signup required
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section id="features" className="relative px-6 py-20">
        <div className="relative z-10 mx-auto max-w-6xl">
          <h2 className="mb-16 text-center text-3xl font-bold md:text-4xl">
            <span className="bg-gradient-to-r from-pink-300 via-purple-300 to-indigo-300 bg-clip-text text-transparent">
              Powerful Features
            </span>
          </h2>

          <div className="grid gap-8 md:grid-cols-3">
            <div className="group relative rounded-3xl border border-white/10 bg-white/5 p-8 backdrop-blur-xl transition-all hover:scale-105 hover:border-purple-500/50 hover:shadow-2xl hover:shadow-purple-500/20">
              <div className="absolute inset-0 rounded-3xl bg-gradient-to-br from-purple-600/10 via-transparent to-transparent opacity-0 transition-opacity group-hover:opacity-100"></div>
              <div className="relative">
                <div className="mb-6 flex h-14 w-14 items-center justify-center rounded-2xl bg-gradient-to-br from-purple-500 to-pink-500 shadow-lg shadow-purple-500/50">
                  <Globe className="h-7 w-7 text-white" />
                </div>
                <h3 className="mb-3 bg-gradient-to-r from-purple-300 to-pink-300 bg-clip-text text-xl font-bold text-transparent">
                  100+ Languages
                </h3>
                <p className="text-neutral-300">
                  Speak in any language and get instant translations to English
                </p>
              </div>
            </div>

            <div className="group relative rounded-3xl border border-white/10 bg-white/5 p-8 backdrop-blur-xl transition-all hover:scale-105 hover:border-blue-500/50 hover:shadow-2xl hover:shadow-blue-500/20">
              <div className="absolute inset-0 rounded-3xl bg-gradient-to-br from-blue-600/10 via-transparent to-transparent opacity-0 transition-opacity group-hover:opacity-100"></div>
              <div className="relative">
                <div className="mb-6 flex h-14 w-14 items-center justify-center rounded-2xl bg-gradient-to-br from-blue-500 to-cyan-500 shadow-lg shadow-blue-500/50">
                  <Shield className="h-7 w-7 text-white" />
                </div>
                <h3 className="mb-3 bg-gradient-to-r from-blue-300 to-cyan-300 bg-clip-text text-xl font-bold text-transparent">
                  Private & Secure
                </h3>
                <p className="text-neutral-300">
                  Everything stays on your device. No cloud, no tracking
                </p>
              </div>
            </div>

            <div className="group relative rounded-3xl border border-white/10 bg-white/5 p-8 backdrop-blur-xl transition-all hover:scale-105 hover:border-pink-500/50 hover:shadow-2xl hover:shadow-pink-500/20">
              <div className="absolute inset-0 rounded-3xl bg-gradient-to-br from-pink-600/10 via-transparent to-transparent opacity-0 transition-opacity group-hover:opacity-100"></div>
              <div className="relative">
                <div className="mb-6 flex h-14 w-14 items-center justify-center rounded-2xl bg-gradient-to-br from-pink-500 to-fuchsia-500 shadow-lg shadow-pink-500/50">
                  <Zap className="h-7 w-7 text-white" />
                </div>
                <h3 className="mb-3 bg-gradient-to-r from-pink-300 to-fuchsia-300 bg-clip-text text-xl font-bold text-transparent">
                  Lightning Fast
                </h3>
                <p className="text-neutral-300">
                  No WiFi required. Use it anywhere, anytime
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Social Proof Stats */}
      <section className="relative px-6 py-20">
        <div className="relative z-10 mx-auto max-w-6xl">
          <div className="grid gap-8 md:grid-cols-4">
            <div className="group rounded-2xl border border-white/10 bg-white/5 p-6 text-center backdrop-blur-xl transition-all hover:border-purple-500/50">
              <div className="mb-3 flex justify-center">
                <TrendingUp className="h-8 w-8 text-purple-400" />
              </div>
              <div className="mb-2 bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text text-5xl font-bold text-transparent">
                87%
              </div>
              <div className="text-neutral-400">Faster Writing</div>
            </div>
            <div className="group rounded-2xl border border-white/10 bg-white/5 p-6 text-center backdrop-blur-xl transition-all hover:border-blue-500/50">
              <div className="mb-3 flex justify-center">
                <Users className="h-8 w-8 text-blue-400" />
              </div>
              <div className="mb-2 bg-gradient-to-r from-blue-400 to-cyan-400 bg-clip-text text-5xl font-bold text-transparent">
                500K+
              </div>
              <div className="text-neutral-400">Active Users</div>
            </div>
            <div className="group rounded-2xl border border-white/10 bg-white/5 p-6 text-center backdrop-blur-xl transition-all hover:border-pink-500/50">
              <div className="mb-3 flex justify-center">
                <Globe className="h-8 w-8 text-pink-400" />
              </div>
              <div className="mb-2 bg-gradient-to-r from-pink-400 to-orange-400 bg-clip-text text-5xl font-bold text-transparent">
                100+
              </div>
              <div className="text-neutral-400">Languages</div>
            </div>
            <div className="group rounded-2xl border border-white/10 bg-white/5 p-6 text-center backdrop-blur-xl transition-all hover:border-green-500/50">
              <div className="mb-3 flex justify-center">
                <Award className="h-8 w-8 text-green-400" />
              </div>
              <div className="mb-2 bg-gradient-to-r from-green-400 to-emerald-400 bg-clip-text text-5xl font-bold text-transparent">
                4.9/5
              </div>
              <div className="text-neutral-400">User Rating</div>
            </div>
          </div>
        </div>
      </section>

      {/* Testimonials Section */}
      <section id="testimonials" className="relative px-6 py-20">
        <div className="relative z-10 mx-auto max-w-6xl">
          <h2 className="mb-4 text-center text-3xl font-bold md:text-4xl">
            <span className="bg-gradient-to-r from-yellow-300 via-orange-300 to-pink-300 bg-clip-text text-transparent">
              Loved by Creators Worldwide
            </span>
          </h2>
          <p className="mx-auto mb-16 max-w-2xl text-center text-neutral-400">
            Join thousands of writers, journalists, and content creators who use
            Talkies daily
          </p>

          <div className="grid gap-8 md:grid-cols-3">
            <div className="group relative rounded-3xl border border-white/10 bg-white/5 p-8 backdrop-blur-xl transition-all hover:border-purple-500/50">
              <div className="absolute inset-0 rounded-3xl bg-gradient-to-br from-purple-600/10 via-transparent to-transparent opacity-0 transition-opacity group-hover:opacity-100"></div>
              <div className="relative">
                <div className="mb-4 flex gap-1">
                  {[...Array(5)].map((_, i) => (
                    <Star
                      key={i}
                      className="h-5 w-5 fill-yellow-400 text-yellow-400"
                    />
                  ))}
                </div>
                <p className="mb-6 leading-relaxed text-neutral-300">
                  &quot;Talkies has completely transformed my workflow. I can
                  now write articles 3x faster just by speaking my thoughts.
                  Game changer!&quot;
                </p>
                <div className="flex items-center gap-3">
                  <div className="flex h-12 w-12 items-center justify-center rounded-full bg-gradient-to-br from-purple-600 to-pink-600 font-bold">
                    SM
                  </div>
                  <div>
                    <div className="font-semibold">Sarah Miller</div>
                    <div className="text-sm text-neutral-400">
                      Tech Journalist
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div className="group relative rounded-3xl border border-white/10 bg-white/5 p-8 backdrop-blur-xl transition-all hover:border-blue-500/50">
              <div className="absolute inset-0 rounded-3xl bg-gradient-to-br from-blue-600/10 via-transparent to-transparent opacity-0 transition-opacity group-hover:opacity-100"></div>
              <div className="relative">
                <div className="mb-4 flex gap-1">
                  {[...Array(5)].map((_, i) => (
                    <Star
                      key={i}
                      className="h-5 w-5 fill-yellow-400 text-yellow-400"
                    />
                  ))}
                </div>
                <p className="mb-6 leading-relaxed text-neutral-300">
                  &quot;The accuracy is incredible. Works perfectly offline and
                  my data stays private. Exactly what I needed for client
                  meetings.&quot;
                </p>
                <div className="flex items-center gap-3">
                  <div className="flex h-12 w-12 items-center justify-center rounded-full bg-gradient-to-br from-blue-600 to-cyan-600 font-bold">
                    JD
                  </div>
                  <div>
                    <div className="font-semibold">James Davis</div>
                    <div className="text-sm text-neutral-400">
                      Product Manager
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div className="group relative rounded-3xl border border-white/10 bg-white/5 p-8 backdrop-blur-xl transition-all hover:border-pink-500/50">
              <div className="absolute inset-0 rounded-3xl bg-gradient-to-br from-pink-600/10 via-transparent to-transparent opacity-0 transition-opacity group-hover:opacity-100"></div>
              <div className="relative">
                <div className="mb-4 flex gap-1">
                  {[...Array(5)].map((_, i) => (
                    <Star
                      key={i}
                      className="h-5 w-5 fill-yellow-400 text-yellow-400"
                    />
                  ))}
                </div>
                <p className="mb-6 leading-relaxed text-neutral-300">
                  &quot;As a non-native English speaker, Talkies helps me write
                  professional emails effortlessly. The multi-language support
                  is fantastic!&quot;
                </p>
                <div className="flex items-center gap-3">
                  <div className="flex h-12 w-12 items-center justify-center rounded-full bg-gradient-to-br from-pink-600 to-orange-600 font-bold">
                    ML
                  </div>
                  <div>
                    <div className="font-semibold">Maria Lopez</div>
                    <div className="text-sm text-neutral-400">
                      Content Creator
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Pricing Section */}
      <section id="pricing" className="relative px-6 py-20">
        <div className="relative z-10 mx-auto max-w-5xl">
          <h2 className="mb-16 text-center text-3xl font-bold md:text-4xl">
            <span className="bg-gradient-to-r from-cyan-300 via-blue-300 to-purple-300 bg-clip-text text-transparent">
              Simple Pricing
            </span>
          </h2>

          <div className="mx-auto grid max-w-4xl gap-8 md:grid-cols-2">
            <div className="group rounded-3xl border border-white/10 bg-white/5 p-8 backdrop-blur-xl transition-all hover:scale-105 hover:border-cyan-500/50">
              <h3 className="mb-2 bg-gradient-to-r from-cyan-300 to-blue-300 bg-clip-text text-2xl font-bold text-transparent">
                Free
              </h3>
              <div className="mb-6 bg-gradient-to-r from-cyan-400 to-blue-400 bg-clip-text text-5xl font-bold text-transparent">
                $0
              </div>
              <ul className="mb-8 space-y-3">
                <li className="flex items-start">
                  <Check className="mt-0.5 mr-3 h-5 w-5 flex-shrink-0 text-green-400" />
                  <span className="text-neutral-200">
                    Basic voice transcription
                  </span>
                </li>
                <li className="flex items-start">
                  <Check className="mt-0.5 mr-3 h-5 w-5 flex-shrink-0 text-green-400" />
                  <span className="text-neutral-200">10 minutes per day</span>
                </li>
                <li className="flex items-start">
                  <Check className="mt-0.5 mr-3 h-5 w-5 flex-shrink-0 text-green-400" />
                  <span className="text-neutral-200">All core features</span>
                </li>
              </ul>
              <button
                onClick={() => {
                  setAuthMode("signup");
                  setAuthModalOpen(true);
                }}
                className="w-full rounded-full border border-white/20 bg-white/10 py-4 font-semibold backdrop-blur-xl transition-all hover:bg-white/20 hover:shadow-lg hover:shadow-cyan-500/20"
              >
                Download Free
              </button>
            </div>

            <div className="group relative overflow-hidden rounded-3xl p-8 transition-all hover:scale-105">
              <div className="animate-gradient absolute inset-0 bg-gradient-to-br from-purple-600 via-pink-600 to-blue-600"></div>
              <div className="absolute inset-[2px] rounded-3xl bg-[#0a0a0f] backdrop-blur-xl"></div>

              <div className="relative">
                <div className="absolute -top-6 left-1/2 -translate-x-1/2 rounded-full bg-gradient-to-r from-yellow-400 to-orange-400 px-6 py-2 text-sm font-bold text-black shadow-lg shadow-yellow-500/50">
                  Popular
                </div>
                <h3 className="mt-4 mb-2 bg-gradient-to-r from-purple-300 to-pink-300 bg-clip-text text-2xl font-bold text-transparent">
                  Pro
                </h3>
                <div className="mb-6 text-5xl font-bold">
                  <span className="bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text text-transparent">
                    $10
                  </span>
                  <span className="text-lg text-neutral-400">/month</span>
                </div>
                <ul className="mb-8 space-y-3">
                  <li className="flex items-start">
                    <Check className="mt-0.5 mr-3 h-5 w-5 flex-shrink-0 text-green-400" />
                    <span className="text-neutral-200">
                      Unlimited transcription
                    </span>
                  </li>
                  <li className="flex items-start">
                    <Check className="mt-0.5 mr-3 h-5 w-5 flex-shrink-0 text-green-400" />
                    <span className="text-neutral-200">100+ languages</span>
                  </li>
                  <li className="flex items-start">
                    <Check className="mt-0.5 mr-3 h-5 w-5 flex-shrink-0 text-green-400" />
                    <span className="text-neutral-200">Custom vocabulary</span>
                  </li>
                  <li className="flex items-start">
                    <Check className="mt-0.5 mr-3 h-5 w-5 flex-shrink-0 text-green-400" />
                    <span className="text-neutral-200">Priority support</span>
                  </li>
                </ul>
                <button
                  onClick={() => setCheckoutModalOpen(true)}
                  className="group/btn relative w-full overflow-hidden rounded-full py-4 font-bold transition-all hover:shadow-2xl hover:shadow-purple-500/50"
                >
                  <div className="animate-gradient-fast absolute inset-0 bg-gradient-to-r from-purple-500 via-pink-500 to-blue-500"></div>
                  <span className="relative text-white">Get Pro</span>
                </button>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Final CTA Section */}
      <section className="relative px-6 py-20">
        <div className="relative mx-auto max-w-4xl">
          {/* Gradient border container */}
          <div className="relative overflow-hidden rounded-3xl">
            <div className="animate-gradient absolute inset-0 bg-gradient-to-br from-purple-600 via-pink-600 to-blue-600"></div>
            <div className="absolute inset-[2px] rounded-3xl bg-[#0a0a0f]"></div>

            <div className="relative p-12 text-center">
              <h2 className="mb-6 text-4xl font-bold md:text-5xl">
                <span className="bg-gradient-to-r from-purple-300 via-pink-300 to-blue-300 bg-clip-text text-transparent">
                  Ready to write faster?
                </span>
              </h2>
              <p className="mx-auto mb-8 max-w-2xl text-xl text-neutral-300">
                Join 500,000+ users who are already transforming their workflow
                with Talkies
              </p>

              <div className="flex flex-col items-center justify-center gap-4 sm:flex-row">
                <button
                  onClick={() => setCheckoutModalOpen(true)}
                  className="group relative overflow-hidden rounded-full px-10 py-5 text-lg font-bold transition-all hover:scale-105 hover:shadow-2xl hover:shadow-purple-500/50"
                >
                  <div className="animate-gradient-fast absolute inset-0 bg-gradient-to-r from-purple-600 via-pink-600 to-blue-600"></div>
                  <div className="absolute inset-0 bg-gradient-to-r from-purple-600 via-pink-600 to-blue-600 opacity-0 blur-xl transition-opacity group-hover:opacity-100"></div>
                  <span className="relative flex items-center gap-2 text-white">
                    <Sparkles className="h-5 w-5" />
                    Start Free Trial
                    <ArrowRight className="h-5 w-5" />
                  </span>
                </button>
                <button
                  onClick={() => {
                    setAuthMode("signup");
                    setAuthModalOpen(true);
                  }}
                  className="rounded-full border border-white/20 bg-white/10 px-10 py-5 text-lg font-bold backdrop-blur-xl transition-all hover:bg-white/20"
                >
                  Try Free Version
                </button>
              </div>

              <div className="mt-8 flex items-center justify-center gap-8 text-sm text-neutral-400">
                <div className="flex items-center gap-2">
                  <Check className="h-5 w-5 text-green-400" />
                  No credit card required
                </div>
                <div className="flex items-center gap-2">
                  <Check className="h-5 w-5 text-green-400" />
                  Cancel anytime
                </div>
                <div className="flex items-center gap-2">
                  <Check className="h-5 w-5 text-green-400" />
                  14-day money back
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* FAQ Section */}
      <section id="faq" className="relative px-6 py-20">
        <div className="relative z-10 mx-auto max-w-3xl">
          <h2 className="mb-16 text-center text-3xl font-bold md:text-4xl">
            <span className="bg-gradient-to-r from-green-300 via-emerald-300 to-teal-300 bg-clip-text text-transparent">
              Frequently Asked Questions
            </span>
          </h2>

          <div className="space-y-6">
            <details className="group rounded-2xl border border-white/10 bg-white/5 p-6 backdrop-blur-xl transition-all hover:border-green-500/50">
              <summary className="cursor-pointer bg-gradient-to-r from-green-300 to-emerald-300 bg-clip-text text-lg font-semibold text-transparent">
                How does the voice transcription work?
              </summary>
              <p className="mt-4 leading-relaxed text-neutral-300">
                Our app uses advanced speech recognition technology that runs
                directly on your device, ensuring privacy and offline
                functionality.
              </p>
            </details>

            <details className="group rounded-2xl border border-white/10 bg-white/5 p-6 backdrop-blur-xl transition-all hover:border-blue-500/50">
              <summary className="cursor-pointer bg-gradient-to-r from-blue-300 to-cyan-300 bg-clip-text text-lg font-semibold text-transparent">
                Is my data secure?
              </summary>
              <p className="mt-4 leading-relaxed text-neutral-300">
                Yes! Everything stays on your device. We never upload your voice
                recordings or transcriptions to the cloud.
              </p>
            </details>

            <details className="group rounded-2xl border border-white/10 bg-white/5 p-6 backdrop-blur-xl transition-all hover:border-purple-500/50">
              <summary className="cursor-pointer bg-gradient-to-r from-purple-300 to-pink-300 bg-clip-text text-lg font-semibold text-transparent">
                Can I use it offline?
              </summary>
              <p className="mt-4 leading-relaxed text-neutral-300">
                Absolutely! The app works completely offline once installed. No
                internet connection required.
              </p>
            </details>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="relative border-t border-white/10 bg-white/5 px-6 py-12 backdrop-blur-xl">
        <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-6 md:flex-row">
          <div className="text-neutral-400">
            © 2025{" "}
            <span className="bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text font-semibold text-transparent">
              Talkies
            </span>
            . All rights reserved.
          </div>
          <div className="flex gap-6">
            <a
              href="#"
              className="text-neutral-400 transition-all hover:scale-110 hover:bg-gradient-to-r hover:from-purple-400 hover:to-pink-400 hover:bg-clip-text hover:text-transparent hover:text-white"
            >
              Privacy
            </a>
            <a
              href="#"
              className="text-neutral-400 transition-all hover:scale-110 hover:bg-gradient-to-r hover:from-blue-400 hover:to-cyan-400 hover:bg-clip-text hover:text-transparent hover:text-white"
            >
              Terms
            </a>
            <a
              href="#"
              className="text-neutral-400 transition-all hover:scale-110 hover:bg-gradient-to-r hover:from-pink-400 hover:to-orange-400 hover:bg-clip-text hover:text-transparent hover:text-white"
            >
              Contact
            </a>
          </div>
        </div>
      </footer>
    </div>
  );
}
