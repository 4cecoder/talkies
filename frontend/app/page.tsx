import { Suspense } from 'react';
import dynamic from 'next/dynamic';
import { Header } from './components/sections/Header';
import { FAQSkeleton } from './components/ui/Skeleton';
import { Globe, Shield, Zap, Sparkles, Download, Apple, Monitor, Terminal, Github } from './components/icons';
import { LiveTranscriptionDemo } from './components/demo/LiveTranscriptionDemo';

const GITHUB_REPO_URL = 'https://github.com/4cecoder/talkies';
const RELEASES_URL = `${GITHUB_REPO_URL}/releases/latest`;

const platforms = [
  {
    name: 'macOS',
    icon: Apple,
    status: 'Ready',
    statusColor: 'text-green-400 border-green-500/30 bg-green-500/10',
    description: 'Apple Silicon, macOS 15+. Powered by WhisperKit.',
    href: RELEASES_URL,
    cta: 'Get the .tar.gz',
  },
  {
    name: 'Windows',
    icon: Monitor,
    status: 'Ready',
    statusColor: 'text-green-400 border-green-500/30 bg-green-500/10',
    description: 'Windows 10/11 (64-bit). Powered by Whisper.net. Dark mode polish still in progress.',
    href: RELEASES_URL,
    cta: 'Get the .zip',
  },
  {
    name: 'Linux',
    icon: Terminal,
    status: 'Available',
    statusColor: 'text-blue-400 border-blue-500/30 bg-blue-500/10',
    description: 'X11 & Wayland, GPU accelerated (Zig + whisper.cpp). Newer and less polished than mac/Windows.',
    href: RELEASES_URL,
    cta: 'Get the .tar.gz',
  },
];

// Lazy load below-fold sections for code splitting
const FAQ = dynamic(() => import('./components/sections/FAQ').then(mod => ({ default: mod.FAQ })), {
  ssr: true,
});

export default function Home() {
  return (
    <div className="min-h-screen bg-[#0a0a0f] text-white relative overflow-hidden" role="document">
      {/* Animated gradient background orbs */}
      <div className="fixed inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-0 -left-1/4 w-[800px] h-[800px] rounded-full bg-gradient-to-br from-purple-600/30 via-violet-600/20 to-transparent blur-3xl animate-glow"></div>
        <div className="absolute top-1/4 -right-1/4 w-[600px] h-[600px] rounded-full bg-gradient-to-bl from-blue-600/30 via-cyan-600/20 to-transparent blur-3xl animate-glow" style={{animationDelay: "1s"}}></div>
        <div className="absolute bottom-0 left-1/3 w-[700px] h-[700px] rounded-full bg-gradient-to-tr from-pink-600/25 via-fuchsia-600/15 to-transparent blur-3xl animate-glow" style={{animationDelay: "2s"}}></div>
      </div>

      <Header />

      <main>
        {/* Hero Section */}
        <section className="relative pt-32 pb-20 px-6" aria-labelledby="hero-heading">
        <div className="max-w-4xl mx-auto text-center relative z-10">
          <div className="flex justify-center mb-4">
            <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full backdrop-blur-xl bg-white/5 border border-white/10">
              <Sparkles className="w-4 h-4 text-yellow-400" />
              <span className="text-sm text-neutral-300">Free & open source</span>
            </div>
          </div>
          <h1 id="hero-heading" className="text-5xl md:text-7xl font-bold mb-6 leading-tight">
            <span className="bg-gradient-to-r from-purple-300 via-pink-300 to-blue-300 bg-clip-text text-transparent animate-gradient">
              Voice transcription
            </span>
            <br />
            <span className="bg-gradient-to-r from-blue-300 via-cyan-300 to-purple-300 bg-clip-text text-transparent animate-gradient">
              that runs entirely on YOUR device
            </span>
          </h1>
          <p className="text-xl md:text-2xl text-neutral-300 mb-12 max-w-2xl mx-auto">
            Talkies turns speech into text on-device, offline, with no account and nothing ever
            uploaded. Pick your platform below.
          </p>

          {/* Platform Picker */}
          <div id="platforms" className="grid sm:grid-cols-2 gap-4 text-left mb-6 scroll-mt-24">
            {platforms.map((platform) => (
              <a
                key={platform.name}
                href={platform.href}
                target="_blank"
                rel="noopener noreferrer"
                className="group relative flex flex-col gap-3 p-6 rounded-2xl backdrop-blur-xl bg-white/5 border border-white/10 hover:border-purple-500/50 transition-all hover:scale-[1.02]"
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center shrink-0">
                      <platform.icon className="w-5 h-5 text-white" />
                    </div>
                    <span className="text-lg font-bold text-white">{platform.name}</span>
                  </div>
                  <span className={`text-xs font-semibold px-2.5 py-1 rounded-full border ${platform.statusColor}`}>
                    {platform.status}
                  </span>
                </div>
                <p className="text-sm text-neutral-400">{platform.description}</p>
                <span className="mt-1 inline-flex items-center gap-1.5 text-sm font-semibold text-purple-300 group-hover:text-purple-200">
                  <Download className="w-4 h-4" />
                  {platform.cta}
                </span>
              </a>
            ))}
          </div>

          <div className="text-sm text-neutral-400">
            100% on-device • No account required • Free, forever
          </div>
        </div>
      </section>

      {/* Live ML Demo Section */}
      <section className="relative py-20 px-6">
        <div className="mx-auto max-w-4xl text-center mb-12">
          <h2 className="text-4xl md:text-5xl font-bold mb-4">
            <span className="bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text text-transparent">
              Try It Now - Right in Your Browser
            </span>
          </h2>
          <p className="text-lg text-neutral-400 max-w-2xl mx-auto">
            Powered by AI running on <span className="text-purple-300 font-semibold">YOUR device</span>. No signup, no cloud, 100% private.
          </p>
        </div>
        <LiveTranscriptionDemo />
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
                  Free, open source, forever
                </span>
              </h2>
              <p className="text-xl text-neutral-300 mb-8 max-w-2xl mx-auto">
                No accounts, no subscriptions, no tracking. Grab a build, read the code, or help build it.
              </p>

              <div className="flex flex-col sm:flex-row gap-4 justify-center items-center">
                <a
                  href={GITHUB_REPO_URL}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="group relative px-10 py-5 rounded-full font-bold overflow-hidden transition-all hover:scale-105 hover:shadow-2xl hover:shadow-purple-500/50 text-lg"
                >
                  <div className="absolute inset-0 bg-gradient-to-r from-purple-600 via-pink-600 to-blue-600 animate-gradient-fast"></div>
                  <div className="absolute inset-0 bg-gradient-to-r from-purple-600 via-pink-600 to-blue-600 opacity-0 group-hover:opacity-100 blur-xl transition-opacity"></div>
                  <span className="relative text-white flex items-center gap-2">
                    <Github className="w-5 h-5" />
                    View on GitHub
                  </span>
                </a>
                <a
                  href="#platforms"
                  className="px-10 py-5 rounded-full font-bold backdrop-blur-xl bg-white/10 border border-white/20 hover:bg-white/20 transition-all text-lg"
                >
                  Choose your platform
                </a>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* FAQ Section - Lazy loaded */}
      <Suspense fallback={<FAQSkeleton />}>
        <FAQ />
      </Suspense>
      </main>



      {/* Footer */}
      <footer className="relative py-12 px-6 border-t border-white/10 backdrop-blur-xl bg-white/5">
        <div className="max-w-6xl mx-auto flex flex-col md:flex-row justify-between items-center gap-6">
          <div className="text-neutral-400">
            © 2026 <span className="bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text text-transparent font-semibold">Talkies</span>. Free & open source.
          </div>
          <div className="flex gap-6">
            <a href="/legal/privacy" className="text-neutral-400 hover:text-white transition-all hover:scale-110 hover:bg-gradient-to-r hover:from-purple-400 hover:to-pink-400 hover:bg-clip-text hover:text-transparent">Privacy</a>
            <a href="/legal/terms" className="text-neutral-400 hover:text-white transition-all hover:scale-110 hover:bg-gradient-to-r hover:from-blue-400 hover:to-cyan-400 hover:bg-clip-text hover:text-transparent">Terms</a>
            <a href="/contact" className="text-neutral-400 hover:text-white transition-all hover:scale-110 hover:bg-gradient-to-r hover:from-pink-400 hover:to-orange-400 hover:bg-clip-text hover:text-transparent">Contact</a>
            <a href={GITHUB_REPO_URL} target="_blank" rel="noopener noreferrer" className="text-neutral-400 hover:text-white transition-all hover:scale-110 hover:bg-gradient-to-r hover:from-green-400 hover:to-cyan-400 hover:bg-clip-text hover:text-transparent">GitHub</a>
          </div>
        </div>
      </footer>
    </div>
  );
}
