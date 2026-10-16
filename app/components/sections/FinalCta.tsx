import Link from 'next/link';
import { Github } from '../icons';
import { PrimaryDownload } from '../hero/PrimaryDownload';
import { GITHUB_REPO_URL } from '@/app/lib/site';

export function FinalCta() {
  return (
    <section aria-labelledby="cta-heading" className="relative px-4 pb-20 sm:px-6 sm:pb-28">
      <div className="card relative mx-auto max-w-6xl overflow-hidden px-6 py-16 text-center sm:px-12 sm:py-20" data-reveal>
        <div className="hero-fallback pointer-events-none absolute inset-0 opacity-90" aria-hidden="true" />
        <div className="grid-fade pointer-events-none absolute inset-0 opacity-60" aria-hidden="true" />
        <div className="relative">
          <h2 id="cta-heading" className="display mx-auto max-w-2xl text-[2.1rem] font-semibold text-fg sm:text-5xl">
            Your words, on your machine.
          </h2>
          <p className="mx-auto mt-4 max-w-lg text-[17px] leading-relaxed text-fg-2">
            Free, open source and private by construction. Download a build or read every line first.
          </p>
          <div className="mt-8 flex flex-col items-center justify-center gap-3 sm:flex-row">
            <PrimaryDownload />
            <Link
              href="/download"
              className="inline-flex h-12 items-center justify-center rounded-full border border-line-strong bg-surface px-6 text-[15px] font-medium text-fg transition-colors hover:bg-surface-2"
            >
              All platforms
            </Link>
          </div>
          <a
            href={GITHUB_REPO_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="mt-6 inline-flex items-center gap-2 text-[14px] text-fg-2 hover:text-fg"
          >
            <Github className="h-4 w-4" aria-hidden="true" />
            4cecoder/talkies
            <span className="sr-only"> on GitHub (opens in a new tab)</span>
          </a>
        </div>
      </div>
    </section>
  );
}
