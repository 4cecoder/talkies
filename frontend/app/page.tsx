import { ModalManager } from './components/ModalManager';
import { Header } from './components/sections/Header';
import { AuthButton } from './components/AuthButton';
import { CheckoutButton } from './components/CheckoutButton';
import { Globe, Shield, TrendingUp, Users, Award, Zap, Check, ArrowRight, Sparkles, Download, Star } from 'lucide-react';

export default function Home() {
  return (
    <div className="min-h-screen bg-[#0a0a0f] text-white relative overflow-hidden">
      {/* Animated gradient background orbs */}
      <div className="fixed inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-0 -left-1/4 w-[800px] h-[800px] rounded-full bg-gradient-to-br from-purple-600/30 via-violet-600/20 to-transparent blur-3xl animate-glow"></div>
        <div className="absolute top-1/4 -right-1/4 w-[600px] h-[600px] rounded-full bg-gradient-to-bl from-blue-600/30 via-cyan-600/20 to-transparent blur-3xl animate-glow" style={{animationDelay: "1s"}}></div>
        <div className="absolute bottom-0 left-1/3 w-[700px] h-[700px] rounded-full bg-gradient-to-tr from-pink-600/25 via-fuchsia-600/15 to-transparent blur-3xl animate-glow" style={{animationDelay: "2s"}}></div>
      </div>

      <Header />
      <ModalManager />

      {/* Hero Section */}
      <section className="relative pt-32 pb-20 px-6">
        <div className="max-w-4xl mx-auto text-center relative z-10">
          <div className="flex justify-center mb-4">
            <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full backdrop-blur-xl bg-white/5 border border-white/10">
              <Sparkles className="w-4 h-4 text-yellow-400" />
              <span className="text-sm text-neutral-300">Voice-Powered AI Writing</span>
            </div>
          </div>
          <h1 className="text-5xl md:text-7xl font-bold mb-6 leading-tight">
            <span className="bg-gradient-to-r from-purple-300 via-pink-300 to-blue-300 bg-clip-text text-transparent animate-gradient">
              Write 3x faster,
            </span>
            <br />
            <span className="bg-gradient-to-r from-blue-300 via-cyan-300 to-purple-300 bg-clip-text text-transparent animate-gradient">
              without lifting a finger
            </span>
          </h1>
          <p className="text-xl md:text-2xl text-neutral-300 mb-12 max-w-2xl mx-auto">
            Voice-powered writing assistant that helps you capture ideas instantly
          </p>

          {/* Download Button - macOS */}
          <div className="flex flex-col gap-6 justify-center items-center mb-8">
            <CheckoutButton
              plan="pro"
              className="group relative px-10 py-5 rounded-full font-semibold overflow-hidden transition-all hover:scale-105 hover:shadow-2xl hover:shadow-purple-500/50"
            >
              <div className="absolute inset-0 bg-gradient-to-r from-purple-600 via-pink-600 to-blue-600 animate-gradient-fast"></div>
              <div className="absolute inset-0 bg-gradient-to-r from-purple-600 via-pink-600 to-blue-600 opacity-0 group-hover:opacity-100 blur-xl transition-opacity"></div>
              <span className="relative text-white font-bold flex items-center gap-2 text-lg">
                <Download className="w-6 h-6" />
                Download for macOS
              </span>
            </CheckoutButton>
            <div className="flex items-center gap-2 text-sm text-neutral-500">
              <span className="px-3 py-1 rounded-full bg-white/5 border border-white/10">
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
      <section id="features" className="relative py-20 px-6">
        <div className="max-w-6xl mx-auto relative z-10">
          <h2 className="text-3xl md:text-4xl font-bold text-center mb-16">
            <span className="bg-gradient-to-r from-pink-300 via-purple-300 to-indigo-300 bg-clip-text text-transparent">
              Powerful Features
            </span>
          </h2>

          <div className="grid md:grid-cols-3 gap-8">
            <div className="group relative p-8 rounded-3xl backdrop-blur-xl bg-white/5 border border-white/10 hover:border-purple-500/50 transition-all hover:scale-105 hover:shadow-2xl hover:shadow-purple-500/20">
              <div className="absolute inset-0 rounded-3xl bg-gradient-to-br from-purple-600/10 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity"></div>
              <div className="relative">
                <div className="w-14 h-14 mb-6 rounded-2xl bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center shadow-lg shadow-purple-500/50">
                  <Globe className="w-7 h-7 text-white" />
                </div>
                <h3 className="text-xl font-bold mb-3 bg-gradient-to-r from-purple-300 to-pink-300 bg-clip-text text-transparent">
                  100+ Languages
                </h3>
                <p className="text-neutral-300">
                  Speak in any language and get instant translations to English
                </p>
              </div>
            </div>

            <div className="group relative p-8 rounded-3xl backdrop-blur-xl bg-white/5 border border-white/10 hover:border-blue-500/50 transition-all hover:scale-105 hover:shadow-2xl hover:shadow-blue-500/20">
              <div className="absolute inset-0 rounded-3xl bg-gradient-to-br from-blue-600/10 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity"></div>
              <div className="relative">
                <div className="w-14 h-14 mb-6 rounded-2xl bg-gradient-to-br from-blue-500 to-cyan-500 flex items-center justify-center shadow-lg shadow-blue-500/50">
                  <Shield className="w-7 h-7 text-white" />
                </div>
                <h3 className="text-xl font-bold mb-3 bg-gradient-to-r from-blue-300 to-cyan-300 bg-clip-text text-transparent">
                  Private & Secure
                </h3>
                <p className="text-neutral-300">
                  Everything stays on your device. No cloud, no tracking
                </p>
              </div>
            </div>

            <div className="group relative p-8 rounded-3xl backdrop-blur-xl bg-white/5 border border-white/10 hover:border-pink-500/50 transition-all hover:scale-105 hover:shadow-2xl hover:shadow-pink-500/20">
              <div className="absolute inset-0 rounded-3xl bg-gradient-to-br from-pink-600/10 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity"></div>
              <div className="relative">
                <div className="w-14 h-14 mb-6 rounded-2xl bg-gradient-to-br from-pink-500 to-fuchsia-500 flex items-center justify-center shadow-lg shadow-pink-500/50">
                  <Zap className="w-7 h-7 text-white" />
                </div>
                <h3 className="text-xl font-bold mb-3 bg-gradient-to-r from-pink-300 to-fuchsia-300 bg-clip-text text-transparent">
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
      <section className="relative py-20 px-6">
        <div className="max-w-6xl mx-auto relative z-10">
          <div className="grid md:grid-cols-4 gap-8">
            <div className="p-6 rounded-2xl backdrop-blur-xl bg-white/5 border border-white/10 text-center group hover:border-purple-500/50 transition-all">
              <div className="flex justify-center mb-3">
                <TrendingUp className="w-8 h-8 text-purple-400" />
              </div>
              <div className="text-5xl font-bold mb-2 bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text text-transparent">
                87%
              </div>
              <div className="text-neutral-400">Faster Writing</div>
            </div>
            <div className="p-6 rounded-2xl backdrop-blur-xl bg-white/5 border border-white/10 text-center group hover:border-blue-500/50 transition-all">
              <div className="flex justify-center mb-3">
                <Users className="w-8 h-8 text-blue-400" />
              </div>
              <div className="text-5xl font-bold mb-2 bg-gradient-to-r from-blue-400 to-cyan-400 bg-clip-text text-transparent">
                500K+
              </div>
              <div className="text-neutral-400">Active Users</div>
            </div>
            <div className="p-6 rounded-2xl backdrop-blur-xl bg-white/5 border border-white/10 text-center group hover:border-pink-500/50 transition-all">
              <div className="flex justify-center mb-3">
                <Globe className="w-8 h-8 text-pink-400" />
              </div>
              <div className="text-5xl font-bold mb-2 bg-gradient-to-r from-pink-400 to-orange-400 bg-clip-text text-transparent">
                100+
              </div>
              <div className="text-neutral-400">Languages</div>
            </div>
            <div className="p-6 rounded-2xl backdrop-blur-xl bg-white/5 border border-white/10 text-center group hover:border-green-500/50 transition-all">
              <div className="flex justify-center mb-3">
                <Award className="w-8 h-8 text-green-400" />
              </div>
              <div className="text-5xl font-bold mb-2 bg-gradient-to-r from-green-400 to-emerald-400 bg-clip-text text-transparent">
                4.9/5
              </div>
              <div className="text-neutral-400">User Rating</div>
            </div>
          </div>
        </div>
      </section>

      {/* Testimonials Section */}
      <section id="testimonials" className="relative py-20 px-6">
        <div className="max-w-6xl mx-auto relative z-10">
          <h2 className="text-3xl md:text-4xl font-bold text-center mb-4">
            <span className="bg-gradient-to-r from-yellow-300 via-orange-300 to-pink-300 bg-clip-text text-transparent">
              Loved by Creators Worldwide
            </span>
          </h2>
          <p className="text-center text-neutral-400 mb-16 max-w-2xl mx-auto">
            Join thousands of writers, journalists, and content creators who use Talkies daily
          </p>

          <div className="grid md:grid-cols-3 gap-8">
            <div className="group relative p-8 rounded-3xl backdrop-blur-xl bg-white/5 border border-white/10 hover:border-purple-500/50 transition-all">
              <div className="absolute inset-0 rounded-3xl bg-gradient-to-br from-purple-600/10 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity"></div>
              <div className="relative">
                <div className="flex gap-1 mb-4">
                  {[...Array(5)].map((_, i) => (
                    <Star key={i} className="w-5 h-5 text-yellow-400 fill-yellow-400" />
                  ))}
                </div>
                <p className="text-neutral-300 mb-6 leading-relaxed">
                  &quot;Talkies has completely transformed my workflow. I can now write articles 3x faster just by speaking my thoughts. Game changer!&quot;
                </p>
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 rounded-full bg-gradient-to-br from-purple-600 to-pink-600 flex items-center justify-center font-bold">
                    SM
                  </div>
                  <div>
                    <div className="font-semibold">Sarah Miller</div>
                    <div className="text-sm text-neutral-400">Tech Journalist</div>
                  </div>
                </div>
              </div>
            </div>

            <div className="group relative p-8 rounded-3xl backdrop-blur-xl bg-white/5 border border-white/10 hover:border-blue-500/50 transition-all">
              <div className="absolute inset-0 rounded-3xl bg-gradient-to-br from-blue-600/10 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity"></div>
              <div className="relative">
                <div className="flex gap-1 mb-4">
                  {[...Array(5)].map((_, i) => (
                    <Star key={i} className="w-5 h-5 text-yellow-400 fill-yellow-400" />
                  ))}
                </div>
                <p className="text-neutral-300 mb-6 leading-relaxed">
                  &quot;The accuracy is incredible. Works perfectly offline and my data stays private. Exactly what I needed for client meetings.&quot;
                </p>
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 rounded-full bg-gradient-to-br from-blue-600 to-cyan-600 flex items-center justify-center font-bold">
                    JD
                  </div>
                  <div>
                    <div className="font-semibold">James Davis</div>
                    <div className="text-sm text-neutral-400">Product Manager</div>
                  </div>
                </div>
              </div>
            </div>

            <div className="group relative p-8 rounded-3xl backdrop-blur-xl bg-white/5 border border-white/10 hover:border-pink-500/50 transition-all">
              <div className="absolute inset-0 rounded-3xl bg-gradient-to-br from-pink-600/10 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity"></div>
              <div className="relative">
                <div className="flex gap-1 mb-4">
                  {[...Array(5)].map((_, i) => (
                    <Star key={i} className="w-5 h-5 text-yellow-400 fill-yellow-400" />
                  ))}
                </div>
                <p className="text-neutral-300 mb-6 leading-relaxed">
                  &quot;As a non-native English speaker, Talkies helps me write professional emails effortlessly. The multi-language support is fantastic!&quot;
                </p>
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 rounded-full bg-gradient-to-br from-pink-600 to-orange-600 flex items-center justify-center font-bold">
                    ML
                  </div>
                  <div>
                    <div className="font-semibold">Maria Lopez</div>
                    <div className="text-sm text-neutral-400">Content Creator</div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Pricing Section */}
      <section id="pricing" className="relative py-20 px-6">
        <div className="max-w-5xl mx-auto relative z-10">
          <h2 className="text-3xl md:text-4xl font-bold text-center mb-16">
            <span className="bg-gradient-to-r from-cyan-300 via-blue-300 to-purple-300 bg-clip-text text-transparent">
              Simple Pricing
            </span>
          </h2>

          <div className="grid md:grid-cols-2 gap-8 max-w-4xl mx-auto">
            <div className="group p-8 rounded-3xl backdrop-blur-xl bg-white/5 border border-white/10 hover:border-cyan-500/50 transition-all hover:scale-105">
              <h3 className="text-2xl font-bold mb-2 bg-gradient-to-r from-cyan-300 to-blue-300 bg-clip-text text-transparent">Free</h3>
              <div className="text-5xl font-bold mb-6 bg-gradient-to-r from-cyan-400 to-blue-400 bg-clip-text text-transparent">$0</div>
              <ul className="space-y-3 mb-8">
                <li className="flex items-start">
                  <Check className="w-5 h-5 text-green-400 mr-3 mt-0.5 flex-shrink-0" />
                  <span className="text-neutral-200">Basic voice transcription</span>
                </li>
                <li className="flex items-start">
                  <Check className="w-5 h-5 text-green-400 mr-3 mt-0.5 flex-shrink-0" />
                  <span className="text-neutral-200">10 minutes per day</span>
                </li>
                <li className="flex items-start">
                  <Check className="w-5 h-5 text-green-400 mr-3 mt-0.5 flex-shrink-0" />
                  <span className="text-neutral-200">All core features</span>
                </li>
              </ul>
              <AuthButton
                mode="signup"
                className="w-full py-4 rounded-full backdrop-blur-xl bg-white/10 border border-white/20 hover:bg-white/20 transition-all font-semibold hover:shadow-lg hover:shadow-cyan-500/20"
              >
                Download Free
              </AuthButton>
            </div>

            <div className="group relative p-8 rounded-3xl overflow-hidden transition-all hover:scale-105">
              <div className="absolute inset-0 bg-gradient-to-br from-purple-600 via-pink-600 to-blue-600 animate-gradient"></div>
              <div className="absolute inset-[2px] rounded-3xl bg-[#0a0a0f] backdrop-blur-xl"></div>

              <div className="relative">
                <div className="absolute -top-6 left-1/2 -translate-x-1/2 px-6 py-2 rounded-full bg-gradient-to-r from-yellow-400 to-orange-400 text-black text-sm font-bold shadow-lg shadow-yellow-500/50">
                  Popular
                </div>
                <h3 className="text-2xl font-bold mb-2 mt-4 bg-gradient-to-r from-purple-300 to-pink-300 bg-clip-text text-transparent">Pro</h3>
                <div className="text-5xl font-bold mb-6">
                  <span className="bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text text-transparent">$10</span>
                  <span className="text-lg text-neutral-400">/month</span>
                </div>
                <ul className="space-y-3 mb-8">
                  <li className="flex items-start">
                    <Check className="w-5 h-5 text-green-400 mr-3 mt-0.5 flex-shrink-0" />
                    <span className="text-neutral-200">Unlimited transcription</span>
                  </li>
                  <li className="flex items-start">
                    <Check className="w-5 h-5 text-green-400 mr-3 mt-0.5 flex-shrink-0" />
                    <span className="text-neutral-200">100+ languages</span>
                  </li>
                  <li className="flex items-start">
                    <Check className="w-5 h-5 text-green-400 mr-3 mt-0.5 flex-shrink-0" />
                    <span className="text-neutral-200">Custom vocabulary</span>
                  </li>
                  <li className="flex items-start">
                    <Check className="w-5 h-5 text-green-400 mr-3 mt-0.5 flex-shrink-0" />
                    <span className="text-neutral-200">Priority support</span>
                  </li>
                </ul>
                <CheckoutButton
                  plan="pro"
                  className="group/btn relative w-full py-4 rounded-full overflow-hidden font-bold transition-all hover:shadow-2xl hover:shadow-purple-500/50"
                >
                  <div className="absolute inset-0 bg-gradient-to-r from-purple-500 via-pink-500 to-blue-500 animate-gradient-fast"></div>
                  <span className="relative text-white">Get Pro</span>
                </CheckoutButton>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Final CTA Section */}
      <section className="relative py-20 px-6">
        <div className="max-w-4xl mx-auto relative">
          {/* Gradient border container */}
          <div className="relative rounded-3xl overflow-hidden">
            <div className="absolute inset-0 bg-gradient-to-br from-purple-600 via-pink-600 to-blue-600 animate-gradient"></div>
            <div className="absolute inset-[2px] rounded-3xl bg-[#0a0a0f]"></div>

            <div className="relative p-12 text-center">
              <h2 className="text-4xl md:text-5xl font-bold mb-6">
                <span className="bg-gradient-to-r from-purple-300 via-pink-300 to-blue-300 bg-clip-text text-transparent">
                  Ready to write faster?
                </span>
              </h2>
              <p className="text-xl text-neutral-300 mb-8 max-w-2xl mx-auto">
                Join 500,000+ users who are already transforming their workflow with Talkies
              </p>

              <div className="flex flex-col sm:flex-row gap-4 justify-center items-center">
                <CheckoutButton
                  plan="pro"
                  className="group relative px-10 py-5 rounded-full font-bold overflow-hidden transition-all hover:scale-105 hover:shadow-2xl hover:shadow-purple-500/50 text-lg"
                >
                  <div className="absolute inset-0 bg-gradient-to-r from-purple-600 via-pink-600 to-blue-600 animate-gradient-fast"></div>
                  <div className="absolute inset-0 bg-gradient-to-r from-purple-600 via-pink-600 to-blue-600 opacity-0 group-hover:opacity-100 blur-xl transition-opacity"></div>
                  <span className="relative text-white flex items-center gap-2">
                    <Sparkles className="w-5 h-5" />
                    Start Free Trial
                    <ArrowRight className="w-5 h-5" />
                  </span>
                </CheckoutButton>
                <AuthButton
                  mode="signup"
                  className="px-10 py-5 rounded-full font-bold backdrop-blur-xl bg-white/10 border border-white/20 hover:bg-white/20 transition-all text-lg"
                >
                  Try Free Version
                </AuthButton>
              </div>

              <div className="mt-8 flex items-center justify-center gap-8 text-sm text-neutral-400">
                <div className="flex items-center gap-2">
                  <Check className="w-5 h-5 text-green-400" />
                  No credit card required
                </div>
                <div className="flex items-center gap-2">
                  <Check className="w-5 h-5 text-green-400" />
                  Cancel anytime
                </div>
                <div className="flex items-center gap-2">
                  <Check className="w-5 h-5 text-green-400" />
                  14-day money back
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* FAQ Section */}
      <section id="faq" className="relative py-20 px-6">
        <div className="max-w-3xl mx-auto relative z-10">
          <h2 className="text-3xl md:text-4xl font-bold text-center mb-16">
            <span className="bg-gradient-to-r from-green-300 via-emerald-300 to-teal-300 bg-clip-text text-transparent">
              Frequently Asked Questions
            </span>
          </h2>

          <div className="space-y-6">
            <details className="group p-6 rounded-2xl backdrop-blur-xl bg-white/5 border border-white/10 hover:border-green-500/50 transition-all">
              <summary className="font-semibold cursor-pointer text-lg bg-gradient-to-r from-green-300 to-emerald-300 bg-clip-text text-transparent">
                How does the voice transcription work?
              </summary>
              <p className="mt-4 text-neutral-300 leading-relaxed">
                Our app uses advanced speech recognition technology that runs directly on your device,
                ensuring privacy and offline functionality.
              </p>
            </details>

            <details className="group p-6 rounded-2xl backdrop-blur-xl bg-white/5 border border-white/10 hover:border-blue-500/50 transition-all">
              <summary className="font-semibold cursor-pointer text-lg bg-gradient-to-r from-blue-300 to-cyan-300 bg-clip-text text-transparent">
                Is my data secure?
              </summary>
              <p className="mt-4 text-neutral-300 leading-relaxed">
                Yes! Everything stays on your device. We never upload your voice recordings or
                transcriptions to the cloud.
              </p>
            </details>

            <details className="group p-6 rounded-2xl backdrop-blur-xl bg-white/5 border border-white/10 hover:border-purple-500/50 transition-all">
              <summary className="font-semibold cursor-pointer text-lg bg-gradient-to-r from-purple-300 to-pink-300 bg-clip-text text-transparent">
                Can I use it offline?
              </summary>
              <p className="mt-4 text-neutral-300 leading-relaxed">
                Absolutely! The app works completely offline once installed. No internet connection required.
              </p>
            </details>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="relative py-12 px-6 border-t border-white/10 backdrop-blur-xl bg-white/5">
        <div className="max-w-6xl mx-auto flex flex-col md:flex-row justify-between items-center gap-6">
          <div className="text-neutral-400">
            © 2025 <span className="bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text text-transparent font-semibold">Talkies</span>. All rights reserved.
          </div>
          <div className="flex gap-6">
            <a href="#" className="text-neutral-400 hover:text-white transition-all hover:scale-110 hover:bg-gradient-to-r hover:from-purple-400 hover:to-pink-400 hover:bg-clip-text hover:text-transparent">Privacy</a>
            <a href="#" className="text-neutral-400 hover:text-white transition-all hover:scale-110 hover:bg-gradient-to-r hover:from-blue-400 hover:to-cyan-400 hover:bg-clip-text hover:text-transparent">Terms</a>
            <a href="#" className="text-neutral-400 hover:text-white transition-all hover:scale-110 hover:bg-gradient-to-r hover:from-pink-400 hover:to-orange-400 hover:bg-clip-text hover:text-transparent">Contact</a>
          </div>
        </div>
      </footer>
    </div>
  );
}
