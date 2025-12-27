import { Button } from '../ui/Button';
import { Download } from 'lucide-react';

export function Hero() {
  return (
    <section className="relative min-h-screen flex items-center justify-center px-6 pt-24 pb-16">
      {/* Animated background orbs */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none" aria-hidden="true">
        <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-purple-600/20 rounded-full blur-3xl animate-glow-pulse"></div>
        <div
          className="absolute top-1/3 right-1/4 w-96 h-96 bg-pink-600/20 rounded-full blur-3xl animate-glow-pulse"
          style={{ animationDelay: '1s' }}
        ></div>
        <div
          className="absolute bottom-1/4 left-1/3 w-96 h-96 bg-blue-600/20 rounded-full blur-3xl animate-glow-pulse"
          style={{ animationDelay: '2s' }}
        ></div>
      </div>

      <div className="relative max-w-4xl mx-auto text-center">
        <h1 className="text-5xl md:text-7xl font-bold mb-6 leading-tight">
          <span className="bg-gradient-to-r from-purple-300 via-pink-300 to-blue-300 bg-clip-text text-transparent animate-gradient">
            AI-Powered Voice Transcription
          </span>
        </h1>

        <p className="text-xl md:text-2xl text-neutral-300 mb-12 max-w-2xl mx-auto">
          Transform your voice into text with lightning-fast accuracy.
          Native macOS app optimized for Apple Silicon.
        </p>

        <div className="flex flex-col gap-6 justify-center items-center mb-8">
          <Button variant="gradient" size="lg" className="gap-2 min-w-[250px] text-lg py-6">
            <Download size={24} aria-hidden="true" />
            Download for macOS
          </Button>
          <p className="text-sm text-neutral-500">
            <span className="px-3 py-1 rounded-full bg-white/5 border border-white/10">
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
