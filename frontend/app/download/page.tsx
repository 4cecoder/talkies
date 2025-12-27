'use client';

import { useState, useEffect } from 'react';
import { Header } from '@/app/components/sections/Header';
import { Download, Check, Apple, Monitor, AlertCircle } from 'lucide-react';

export default function DownloadPage() {
  const [platform, setPlatform] = useState<'mac' | 'windows' | 'linux' | 'unknown'>('unknown');

  useEffect(() => {
    // Detect platform
    const userAgent = window.navigator.userAgent.toLowerCase();
    if (userAgent.indexOf('mac') !== -1) {
      setPlatform('mac');
    } else if (userAgent.indexOf('win') !== -1) {
      setPlatform('windows');
    } else if (userAgent.indexOf('linux') !== -1) {
      setPlatform('linux');
    }
  }, []);

  return (
    <div className="min-h-screen bg-[#0a0a0f] text-white">
      {/* Gradient background */}
      <div className="fixed inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-0 -left-1/4 w-[800px] h-[800px] rounded-full bg-gradient-to-br from-purple-600/20 via-violet-600/10 to-transparent blur-3xl"></div>
        <div className="absolute bottom-0 right-0 w-[600px] h-[600px] rounded-full bg-gradient-to-bl from-pink-600/15 via-fuchsia-600/10 to-transparent blur-3xl"></div>
      </div>

      <Header />

      <main className="relative pt-32 pb-20 px-6">
        <div className="max-w-5xl mx-auto">
          {/* Page Header */}
          <div className="text-center mb-12">
            <h1 className="text-5xl md:text-6xl font-bold mb-4">
              <span className="bg-gradient-to-r from-purple-300 to-pink-300 bg-clip-text text-transparent">
                Download Talkies
              </span>
            </h1>
            <p className="text-lg text-neutral-400">
              Get started with voice transcription on your platform
            </p>
          </div>

          {/* Platform Cards */}
          <div className="grid md:grid-cols-2 gap-6 mb-12">
            {/* macOS */}
            <div className={`rounded-2xl border p-8 backdrop-blur-xl transition-all ${
              platform === 'mac'
                ? 'border-purple-500/50 bg-gradient-to-br from-purple-500/10 to-pink-500/10'
                : 'border-white/10 bg-white/5'
            }`}>
              <div className="flex items-center gap-4 mb-6">
                <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-gradient-to-br from-purple-500 to-pink-500">
                  <Apple className="h-8 w-8 text-white" />
                </div>
                <div>
                  <h2 className="text-2xl font-bold">macOS</h2>
                  {platform === 'mac' && (
                    <span className="text-sm text-green-400">Detected ✓</span>
                  )}
                </div>
              </div>

              <div className="mb-6 space-y-2">
                <div className="flex items-center gap-2 text-sm text-neutral-300">
                  <Check className="h-4 w-4 text-green-400" />
                  <span>Apple Silicon (M1, M2, M3) optimized</span>
                </div>
                <div className="flex items-center gap-2 text-sm text-neutral-300">
                  <Check className="h-4 w-4 text-green-400" />
                  <span>Requires macOS 15+ (Sequoia or later)</span>
                </div>
                <div className="flex items-center gap-2 text-sm text-neutral-300">
                  <Check className="h-4 w-4 text-green-400" />
                  <span>WhisperKit powered - blazing fast</span>
                </div>
                <div className="flex items-center gap-2 text-sm text-neutral-300">
                  <Check className="h-4 w-4 text-green-400" />
                  <span>100+ languages supported</span>
                </div>
              </div>

              <button className="w-full rounded-full bg-gradient-to-r from-purple-500 to-pink-500 px-8 py-4 font-semibold text-white transition-transform hover:scale-105 flex items-center justify-center gap-2">
                <Download className="h-5 w-5" />
                Download for macOS
              </button>

              <p className="text-xs text-center text-neutral-500 mt-3">
                Version 1.0.0 • 45 MB
              </p>
            </div>

            {/* Windows */}
            <div className={`rounded-2xl border p-8 backdrop-blur-xl transition-all ${
              platform === 'windows'
                ? 'border-blue-500/50 bg-gradient-to-br from-blue-500/10 to-cyan-500/10'
                : 'border-white/10 bg-white/5'
            }`}>
              <div className="flex items-center gap-4 mb-6">
                <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-gradient-to-br from-blue-500 to-cyan-500">
                  <Monitor className="h-8 w-8 text-white" />
                </div>
                <div>
                  <h2 className="text-2xl font-bold">Windows</h2>
                  {platform === 'windows' && (
                    <span className="text-sm text-green-400">Detected ✓</span>
                  )}
                </div>
              </div>

              <div className="mb-6 space-y-2">
                <div className="flex items-center gap-2 text-sm text-neutral-300">
                  <Check className="h-4 w-4 text-green-400" />
                  <span>Windows 10/11 (64-bit)</span>
                </div>
                <div className="flex items-center gap-2 text-sm text-neutral-300">
                  <Check className="h-4 w-4 text-green-400" />
                  <span>.NET 8.0 (included in installer)</span>
                </div>
                <div className="flex items-center gap-2 text-sm text-neutral-300">
                  <Check className="h-4 w-4 text-green-400" />
                  <span>Whisper.net powered transcription</span>
                </div>
                <div className="flex items-center gap-2 text-sm text-neutral-300">
                  <Check className="h-4 w-4 text-green-400" />
                  <span>Ollama/LM Studio integration</span>
                </div>
              </div>

              <div className="relative">
                <button
                  disabled
                  className="w-full rounded-full bg-white/5 px-8 py-4 font-semibold text-neutral-500 cursor-not-allowed flex items-center justify-center gap-2 border border-white/10"
                >
                  <AlertCircle className="h-5 w-5" />
                  Coming Soon
                </button>
                <div className="absolute -top-3 right-4 bg-gradient-to-r from-yellow-500 to-orange-500 text-white text-xs font-bold px-3 py-1 rounded-full">
                  Beta Access
                </div>
              </div>

              <p className="text-xs text-center text-neutral-500 mt-3">
                Join waitlist for early access
              </p>
            </div>
          </div>

          {/* Feature Comparison Table */}
          <div className="rounded-2xl border border-white/10 bg-white/5 p-8 backdrop-blur-xl mb-12">
            <h2 className="text-2xl font-bold mb-6 text-center">Feature Comparison</h2>

            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-white/10">
                    <th className="text-left py-3 px-4">Feature</th>
                    <th className="text-center py-3 px-4">Web App</th>
                    <th className="text-center py-3 px-4">Desktop App</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-white/5">
                  <tr>
                    <td className="py-3 px-4">Transcription time</td>
                    <td className="text-center py-3 px-4 text-neutral-400">1 min demo</td>
                    <td className="text-center py-3 px-4 text-green-400">Unlimited</td>
                  </tr>
                  <tr>
                    <td className="py-3 px-4">Languages supported</td>
                    <td className="text-center py-3 px-4 text-neutral-400">20+</td>
                    <td className="text-center py-3 px-4 text-green-400">100+</td>
                  </tr>
                  <tr>
                    <td className="py-3 px-4">Works offline</td>
                    <td className="text-center py-3 px-4 text-neutral-400">No</td>
                    <td className="text-center py-3 px-4 text-green-400">Yes</td>
                  </tr>
                  <tr>
                    <td className="py-3 px-4">Export formats</td>
                    <td className="text-center py-3 px-4 text-neutral-400">Copy only</td>
                    <td className="text-center py-3 px-4 text-green-400">TXT, SRT, VTT</td>
                  </tr>
                  <tr>
                    <td className="py-3 px-4">AI Enhancement</td>
                    <td className="text-center py-3 px-4 text-neutral-400">Basic</td>
                    <td className="text-center py-3 px-4 text-green-400">Advanced</td>
                  </tr>
                  <tr>
                    <td className="py-3 px-4">Hotkey support</td>
                    <td className="text-center py-3 px-4 text-neutral-400">No</td>
                    <td className="text-center py-3 px-4 text-green-400">Yes</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          {/* System Requirements */}
          <div className="grid md:grid-cols-2 gap-6">
            {/* macOS Requirements */}
            <div className="rounded-2xl border border-white/10 bg-white/5 p-6 backdrop-blur-xl">
              <h3 className="text-lg font-semibold mb-4">macOS System Requirements</h3>
              <ul className="space-y-2 text-sm text-neutral-300">
                <li className="flex items-start gap-2">
                  <Check className="h-4 w-4 text-purple-400 mt-0.5" />
                  <span><strong>OS:</strong> macOS 15+ (Sequoia or later)</span>
                </li>
                <li className="flex items-start gap-2">
                  <Check className="h-4 w-4 text-purple-400 mt-0.5" />
                  <span><strong>Chip:</strong> Apple Silicon (M1, M2, M3)</span>
                </li>
                <li className="flex items-start gap-2">
                  <Check className="h-4 w-4 text-purple-400 mt-0.5" />
                  <span><strong>RAM:</strong> 8 GB minimum, 16 GB recommended</span>
                </li>
                <li className="flex items-start gap-2">
                  <Check className="h-4 w-4 text-purple-400 mt-0.5" />
                  <span><strong>Storage:</strong> 200 MB for app + models</span>
                </li>
              </ul>
            </div>

            {/* Windows Requirements */}
            <div className="rounded-2xl border border-white/10 bg-white/5 p-6 backdrop-blur-xl">
              <h3 className="text-lg font-semibold mb-4">Windows System Requirements</h3>
              <ul className="space-y-2 text-sm text-neutral-300">
                <li className="flex items-start gap-2">
                  <Check className="h-4 w-4 text-blue-400 mt-0.5" />
                  <span><strong>OS:</strong> Windows 10 or 11 (64-bit)</span>
                </li>
                <li className="flex items-start gap-2">
                  <Check className="h-4 w-4 text-blue-400 mt-0.5" />
                  <span><strong>Processor:</strong> Intel i5 or AMD equivalent</span>
                </li>
                <li className="flex items-start gap-2">
                  <Check className="h-4 w-4 text-blue-400 mt-0.5" />
                  <span><strong>RAM:</strong> 8 GB minimum, 16 GB recommended</span>
                </li>
                <li className="flex items-start gap-2">
                  <Check className="h-4 w-4 text-blue-400 mt-0.5" />
                  <span><strong>Storage:</strong> 300 MB for app + dependencies</span>
                </li>
              </ul>
            </div>
          </div>

          {/* Help Section */}
          <div className="mt-12 rounded-2xl border border-white/10 bg-gradient-to-br from-white/5 to-transparent p-8 text-center backdrop-blur-xl">
            <h3 className="text-2xl font-semibold mb-2">Need Help Installing?</h3>
            <p className="text-neutral-400 mb-6">
              Check out our installation guide or contact support
            </p>
            <div className="flex flex-col sm:flex-row gap-4 justify-center">
              <a
                href="https://docs.talkies.app"
                className="inline-flex items-center justify-center gap-2 rounded-full border border-white/20 bg-white/5 px-6 py-3 font-semibold text-white transition-colors hover:bg-white/10"
              >
                View Documentation
              </a>
              <a
                href="/contact"
                className="inline-flex items-center justify-center gap-2 rounded-full bg-gradient-to-r from-purple-500 to-pink-500 px-6 py-3 font-semibold text-white transition-transform hover:scale-105"
              >
                Contact Support
              </a>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
