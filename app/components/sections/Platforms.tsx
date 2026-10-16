import { Apple, ArrowUpRight, Check, Monitor, Smartphone, Terminal } from 'lucide-react';
import { SectionHeading } from './SectionHeading';
import { platforms, type PlatformId } from '@/app/lib/site';

const icons: Record<PlatformId, typeof Apple> = {
  mac: Apple,
  windows: Monitor,
  linux: Terminal,
  android: Smartphone,
};

export function Platforms() {
  return (
    <section aria-labelledby="platforms-heading" id="platforms" className="relative py-16 sm:py-24">
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        <SectionHeading
          id="platforms-heading"
          eyebrow="Platforms"
          title="Native everywhere you type."
          lede="Each client is built with its platform's own toolkit, not a web wrapper. Pick yours."
        />

        <ul className="mt-14 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {platforms.map((platform, index) => {
            const Icon = icons[platform.id];
            const isGuide = platform.id === 'android';
            return (
              <li
                key={platform.id}
                className="card group flex flex-col p-6 transition-colors hover:border-line-strong"
                data-reveal
                style={{ '--reveal-delay': `${index * 70}ms` } as React.CSSProperties}
              >
                <div className="flex items-center justify-between">
                  <span className="flex h-11 w-11 items-center justify-center rounded-xl border border-line bg-surface-2 text-fg">
                    <Icon className="h-5 w-5" aria-hidden="true" />
                  </span>
                  <span
                    className={`inline-flex items-center gap-1.5 rounded-full border border-line px-2.5 py-0.5 text-[12px] font-medium ${
                      platform.tone === 'ok' ? 'text-ok' : 'text-warn'
                    }`}
                  >
                    <span className={`h-1.5 w-1.5 rounded-full ${platform.tone === 'ok' ? 'bg-ok' : 'bg-warn'}`} aria-hidden="true" />
                    {platform.status}
                  </span>
                </div>
                <h3 className="mt-6 text-xl font-semibold tracking-tight text-fg">{platform.name}</h3>
                <p className="mt-1 text-[13px] text-fg-3">{platform.stack}</p>
                <ul className="mt-5 flex-1 space-y-2.5">
                  {platform.requirements.map((req) => (
                    <li key={req} className="flex items-start gap-2 text-[14px] text-fg-2">
                      <Check className="mt-0.5 h-4 w-4 shrink-0 text-fg-3" aria-hidden="true" />
                      {req}
                    </li>
                  ))}
                </ul>
                <a
                  href={platform.href}
                  target="_blank"
                  rel="noopener noreferrer"
                  className={`mt-6 inline-flex h-10 items-center justify-center gap-1.5 rounded-full text-[14px] font-medium transition-[opacity,background-color] ${
                    isGuide ? 'border border-line-strong text-fg hover:bg-surface-2' : 'bg-cta text-cta-fg hover:opacity-90'
                  }`}
                >
                  {platform.cta}
                  <ArrowUpRight className="h-3.5 w-3.5" aria-hidden="true" />
                  <span className="sr-only"> (opens GitHub in a new tab)</span>
                </a>
              </li>
            );
          })}
        </ul>

        <p className="mt-6 text-center text-[13px] leading-relaxed text-fg-3" data-reveal>
          Current builds are prereleases from GitHub Releases. Windows packages are unsigned for now. Verify any download
          against the <span className="font-mono">SHA256SUMS</span> file in the same release.
        </p>
      </div>
    </section>
  );
}
