import Link from 'next/link';
import { ArrowRight, Github } from '../icons';
import { HeroWave } from '../hero/HeroWave';
import { PrimaryDownload } from '../hero/PrimaryDownload';
import { GITHUB_REPO_URL, platforms } from '@/app/lib/site';

function DictationMock() {
  return (
    <figure className="relative mx-auto w-full max-w-[34rem]">
      <div className="rounded-[1.4rem] border border-line-strong bg-elev/80 p-1.5 shadow-[0_30px_80px_-30px_rgba(124,58,237,0.55)] backdrop-blur-xl">
        <div className="flex items-center justify-between gap-3 rounded-[1.1rem] border border-line bg-surface px-3.5 py-2.5">
          <div className="flex items-center gap-2.5">
            <span className="rec-dot h-2.5 w-2.5 rounded-full bg-rose-500" aria-hidden="true" />
            <span className="text-[13px] font-medium text-fg">Listening</span>
            <span className="font-mono text-[12px] tabular-nums text-fg-3">0:04</span>
          </div>
          <span className="inline-flex items-center gap-1.5 rounded-full border border-line px-2 py-0.5 text-[11px] font-medium text-fg-2">
            <span className="h-1.5 w-1.5 rounded-full bg-ok" aria-hidden="true" />
            On this device
          </span>
        </div>
        <div className="px-4 pb-3.5 pt-3 text-left">
          <p className="text-[15px] leading-relaxed text-fg">
            <span className="typing inline">Send Maya the draft by Friday and flag the budget numbers.</span>
            <span className="caret ml-0.5 inline-block h-[1.05em] w-[2px] translate-y-[3px] bg-accent" aria-hidden="true" />
          </p>
        </div>
      </div>
      <figcaption className="sr-only">
        Illustration of the Talkies dictation panel listening and typing a sentence, with a badge showing processing happens on this device.
      </figcaption>
    </figure>
  );
}

export function Hero() {
  return (
    <section aria-labelledby="hero-heading" className="relative overflow-hidden pt-28 sm:pt-32">
      <div className="grid-fade pointer-events-none absolute inset-x-0 top-0 h-[38rem]" aria-hidden="true" />

      <div className="relative mx-auto max-w-6xl px-4 text-center sm:px-6">
        <Link
          href="#engines"
          className="group mx-auto inline-flex items-center gap-2 rounded-full border border-line bg-surface py-1 pl-1 pr-3 text-[13px] text-fg-2 transition-colors hover:border-line-strong hover:text-fg"
        >
          <span className="rounded-full bg-gradient-to-r from-[#a855f7] to-[#ec4899] px-2 py-0.5 text-[11px] font-semibold uppercase tracking-wider text-white">
            New
          </span>
          <span>
            Phonon-2 is coming<span className="hidden sm:inline"> as the default English engine</span>
          </span>
          <ArrowRight className="h-3.5 w-3.5 transition-transform group-hover:translate-x-0.5" aria-hidden="true" />
        </Link>

        <h1 id="hero-heading" className="display mx-auto mt-7 max-w-5xl text-[2.6rem] font-semibold text-fg sm:text-6xl md:text-[4rem] lg:text-[4.6rem]">
          Talk. It types.
          <br />
          <span className="text-brand">Nothing leaves your device.</span>
        </h1>

        <p className="mx-auto mt-6 max-w-2xl text-[17px] leading-relaxed text-fg-2 sm:text-lg">
          Talkies is open-source dictation for macOS, Windows, Linux and Android. Hold a hotkey, speak,
          and your words land wherever the cursor is. Recognition, cleanup and typing run locally once
          you have downloaded a model.
        </p>

        <div className="mt-9 flex flex-col items-center justify-center gap-3 sm:flex-row">
          <PrimaryDownload />
          <a
            href={GITHUB_REPO_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex h-12 items-center justify-center gap-2 rounded-full border border-line-strong bg-surface px-6 text-[15px] font-medium text-fg transition-colors hover:bg-surface-2"
          >
            <Github className="h-4 w-4" aria-hidden="true" />
            View source
            <span className="sr-only"> on GitHub (opens in a new tab)</span>
          </a>
        </div>

        <ul className="mx-auto mt-6 flex flex-wrap items-center justify-center gap-x-5 gap-y-2 text-[13px] text-fg-3" aria-label="Supported platforms">
          {platforms.map((p) => (
            <li key={p.id} className="flex items-center gap-1.5">
              <span className={`h-1.5 w-1.5 rounded-full ${p.tone === 'ok' ? 'bg-ok' : 'bg-warn'}`} aria-hidden="true" />
              {p.name}
              {p.tone === 'warn' && <span className="text-fg-3">(early access)</span>}
            </li>
          ))}
        </ul>
      </div>

      {/* Fixed-height band: the canvas never changes layout. */}
      <div className="relative mt-4 h-[17rem] sm:mt-2 sm:h-[21rem] md:h-[23rem]">
        <HeroWave />
        <div className="relative flex h-full items-center px-4 sm:px-6">
          <DictationMock />
        </div>
      </div>
    </section>
  );
}
