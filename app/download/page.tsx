'use client';

import { Apple, ArrowUpRight, Check, Monitor, ShieldCheck, Smartphone, Terminal } from 'lucide-react';
import { QRCodeSVG } from 'qrcode.react';
import { Header } from '@/app/components/sections/Header';
import { Footer } from '@/app/components/sections/Footer';
import { ANDROID_APK_URL, FIRST_RUN_URL, platforms, RELEASES_URL, type PlatformId } from '@/app/lib/site';
import { usePlatform } from '@/app/lib/usePlatform';

const icons: Record<PlatformId, typeof Apple> = {
  mac: Apple,
  windows: Monitor,
  linux: Terminal,
  android: Smartphone,
};

export default function DownloadPage() {
  const detected = usePlatform();

  return (
    <div className="min-h-screen bg-bg text-fg">
      <Header />
      <main id="main" className="relative overflow-hidden px-4 pb-24 pt-32 sm:px-6 sm:pt-40">
        <div className="hero-fallback pointer-events-none absolute inset-x-0 top-0 -z-0 h-[32rem] opacity-70" aria-hidden="true" />
        <div className="relative mx-auto max-w-6xl">
          <header className="max-w-2xl">
            <p className="font-mono text-[12px] font-medium uppercase tracking-[0.18em] text-accent">Download</p>
            <h1 className="display mt-4 text-[2.6rem] font-semibold sm:text-6xl">Get Talkies.</h1>
            <p className="mt-5 text-[17px] leading-relaxed text-fg-2">
              Builds are published on GitHub Releases. The current <span className="font-mono text-[0.92em]">latest</span>{' '}
              channel is a prerelease. On first launch you choose and download a speech model; after that, dictation runs
              offline.
            </p>
          </header>

          <ul className="mt-12 grid gap-4 sm:grid-cols-2">
            {platforms.map((platform) => {
              const Icon = icons[platform.id];
              const isDetected = detected === platform.id;
              return (
                <li
                  key={platform.id}
                  className={`card flex flex-col p-6 sm:p-8 ${isDetected ? 'ring-brand' : ''}`}
                  aria-current={isDetected ? 'true' : undefined}
                >
                  <div className="flex items-start justify-between gap-4">
                    <div className="flex items-center gap-4">
                      <span className="flex h-12 w-12 items-center justify-center rounded-xl border border-line bg-surface-2">
                        <Icon className="h-6 w-6" aria-hidden="true" />
                      </span>
                      <div>
                        <h2 className="text-2xl font-semibold tracking-tight">{platform.name}</h2>
                        <p className="text-[13px] text-fg-3">{platform.stack}</p>
                      </div>
                    </div>
                    <span
                      className={`inline-flex shrink-0 items-center gap-1.5 rounded-full border border-line px-2.5 py-0.5 text-[12px] font-medium ${
                        platform.tone === 'ok' ? 'text-ok' : 'text-warn'
                      }`}
                    >
                      {isDetected ? 'Your device' : platform.status}
                    </span>
                  </div>
                  <ul className="mt-6 flex-1 space-y-2.5">
                    {platform.requirements.map((req) => (
                      <li key={req} className="flex items-start gap-2 text-[15px] text-fg-2">
                        <Check className="mt-0.5 h-4 w-4 shrink-0 text-fg-3" aria-hidden="true" />
                        {req}
                      </li>
                    ))}
                  </ul>
                  {platform.id === 'android' && detected !== 'android' && (
                    <div className="mt-7 flex items-center gap-4 rounded-2xl border border-line bg-surface-2 p-4 sm:gap-5 sm:p-5">
                      <div className="shrink-0 rounded-xl bg-white p-2.5" aria-label="QR code for the Talkies Android APK">
                        <QRCodeSVG
                          value={ANDROID_APK_URL}
                          size={116}
                          level="Q"
                          bgColor="#ffffff"
                          fgColor="#111111"
                          title="Scan to download the Talkies Android APK"
                        />
                      </div>
                      <div>
                        <h3 className="text-[15px] font-semibold text-fg">Install from your phone</h3>
                        <p className="mt-1 text-[13px] leading-relaxed text-fg-2">
                          Scan with your phone camera to open the Android APK download.
                        </p>
                      </div>
                    </div>
                  )}
                  <div className="mt-7 flex flex-col gap-2 sm:flex-row">
                    <a
                      href={platform.href}
                      target="_blank"
                      rel="noopener noreferrer"
                      className={`inline-flex h-11 flex-1 items-center justify-center gap-1.5 rounded-full px-5 text-[15px] font-medium transition-opacity hover:opacity-90 ${
                        platform.id === 'android' ? 'border border-line-strong text-fg' : 'bg-cta text-cta-fg'
                      }`}
                    >
                      {platform.cta}
                      <ArrowUpRight className="h-4 w-4" aria-hidden="true" />
                      <span className="sr-only"> (opens GitHub in a new tab)</span>
                    </a>
                    <a
                      href={platform.guide}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="inline-flex h-11 items-center justify-center rounded-full border border-line-strong px-5 text-[15px] font-medium text-fg transition-colors hover:bg-surface-2"
                    >
                      Setup guide
                      <span className="sr-only"> for {platform.name} (opens GitHub in a new tab)</span>
                    </a>
                  </div>
                </li>
              );
            })}
          </ul>

          <section aria-labelledby="verify-heading" className="card mt-6 flex flex-col gap-5 p-6 sm:flex-row sm:items-center sm:justify-between sm:p-8">
            <div className="flex items-start gap-4">
              <ShieldCheck className="mt-1 h-6 w-6 shrink-0 text-ok" aria-hidden="true" />
              <div>
                <h2 id="verify-heading" className="text-lg font-semibold tracking-tight">
                  Verify what you download
                </h2>
                <p className="mt-1 max-w-xl text-[15px] leading-relaxed text-fg-2">
                  Every release includes a <span className="font-mono text-[0.92em]">SHA256SUMS</span> file. Windows
                  packages are currently unsigned, so compare checksums before installing. Models are checked against
                  pinned SHA-256 hashes inside the app.
                </p>
              </div>
            </div>
            <div className="flex shrink-0 flex-col gap-2 sm:items-end">
              <a href={RELEASES_URL} target="_blank" rel="noopener noreferrer" className="inline-flex items-center gap-1 text-[15px] font-medium text-accent hover:underline">
                All release files
                <ArrowUpRight className="h-4 w-4" aria-hidden="true" />
                <span className="sr-only"> (opens GitHub in a new tab)</span>
              </a>
              <a href={FIRST_RUN_URL} target="_blank" rel="noopener noreferrer" className="inline-flex items-center gap-1 text-[15px] font-medium text-accent hover:underline">
                First-run guide
                <ArrowUpRight className="h-4 w-4" aria-hidden="true" />
                <span className="sr-only"> (opens GitHub in a new tab)</span>
              </a>
            </div>
          </section>
        </div>
      </main>
      <Footer />
    </div>
  );
}
