import { Sparkles } from 'lucide-react';
import { SectionHeading } from './SectionHeading';

interface Spec {
  term: string;
  detail: string;
}

function Specs({ items }: { items: Spec[] }) {
  return (
    <dl className="mt-7 grid grid-cols-1 gap-px overflow-hidden rounded-xl border border-line bg-line sm:grid-cols-3">
      {items.map(({ term, detail }) => (
        <div key={term} className="bg-bg/95 px-4 py-3.5">
          <dt className="font-mono text-[11px] uppercase tracking-[0.14em] text-fg-3">{term}</dt>
          <dd className="mt-1.5 text-[14px] font-medium text-fg">{detail}</dd>
        </div>
      ))}
    </dl>
  );
}

export function Engines() {
  return (
    <section aria-labelledby="engines-heading" id="engines" className="relative py-16 sm:py-24">
      <div className="pointer-events-none absolute inset-x-0 top-1/3 -z-10 h-[30rem] bg-[radial-gradient(50%_50%_at_30%_50%,var(--hero-glow-1),transparent_70%)]" aria-hidden="true" />
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        <SectionHeading
          id="engines-heading"
          eyebrow="Speech engines"
          title="Two engines. One rule: it runs here."
          lede="Phonon-2 will handle English. Whisper covers every other language. Both run entirely on your hardware after a one-time download."
        />

        <div className="mt-14 grid gap-6 lg:grid-cols-2">
          <article className="card ring-brand relative overflow-hidden p-6 sm:p-8" aria-labelledby="engine-phonon" data-reveal>
            <div className="pointer-events-none absolute -right-24 -top-24 h-64 w-64 rounded-full bg-[radial-gradient(closest-side,rgba(168,85,247,0.35),transparent)]" aria-hidden="true" />
            <div className="flex flex-wrap items-center gap-2">
              <span className="rounded-full bg-gradient-to-r from-[#a855f7] to-[#ec4899] px-2.5 py-0.5 text-[11px] font-semibold uppercase tracking-wider text-white">
                Coming soon
              </span>
              <span className="rounded-full border border-line px-2.5 py-0.5 text-[12px] text-fg-2">New default for English</span>
            </div>
            <h3 id="engine-phonon" className="display mt-5 text-4xl font-semibold text-fg">
              Phonon-2
            </h3>
            <p className="mt-3 max-w-md text-[15px] leading-relaxed text-fg-2">
              Fermion Research&apos;s compressed build of NVIDIA Parakeet TDT. A compact English speech model that will
              become the default engine for English dictation.
            </p>
            <Specs
              items={[
                { term: 'Size · Apple Silicon', detail: '~164 MB' },
                { term: 'Language', detail: 'English' },
                { term: 'Runs', detail: 'On-device' },
              ]}
            />
            <p className="mt-5 text-[12px] leading-relaxed text-fg-3">
              Speed and accuracy figures for Phonon-2 are Fermion Research&apos;s own reported numbers, not Talkies
              measurements. We will publish ours when the engine ships.
            </p>
          </article>

          <article className="card relative overflow-hidden p-6 sm:p-8" aria-labelledby="engine-whisper" data-reveal style={{ '--reveal-delay': '100ms' } as React.CSSProperties}>
            <div className="flex flex-wrap items-center gap-2">
              <span className="inline-flex items-center gap-1.5 rounded-full border border-line px-2.5 py-0.5 text-[12px] text-fg-2">
                <span className="h-1.5 w-1.5 rounded-full bg-ok" aria-hidden="true" />
                Available today
              </span>
              <span className="rounded-full border border-line px-2.5 py-0.5 text-[12px] text-fg-2">Fallback for other languages</span>
            </div>
            <h3 id="engine-whisper" className="display mt-5 text-4xl font-semibold text-fg">
              Whisper
            </h3>
            <p className="mt-3 max-w-md text-[15px] leading-relaxed text-fg-2">
              The open multilingual speech model, run through a native runtime on each platform. It powers every Talkies
              build today and stays on for languages beyond English.
            </p>
            <Specs
              items={[
                { term: 'Languages', detail: 'Multilingual' },
                { term: 'Desktop', detail: 'WhisperKit · Whisper.net · whisper.cpp' },
                { term: 'Android', detail: 'Whisper tiny' },
              ]}
            />
          </article>
        </div>

        <div className="card mt-6 flex flex-col gap-4 p-5 sm:flex-row sm:items-center sm:justify-between sm:p-6" data-reveal>
          <div className="flex items-start gap-4">
            <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl border border-line bg-surface text-accent">
              <Sparkles className="h-[18px] w-[18px]" aria-hidden="true" />
            </span>
            <div>
              <h3 className="text-[16px] font-semibold tracking-tight text-fg">Optional cleanup with S1-mini</h3>
              <p className="mt-1 text-[14px] leading-relaxed text-fg-2">
                A small local language model that tidies punctuation, filler words and tone. Off until you download it.
              </p>
            </div>
          </div>
          <p className="shrink-0 font-mono text-[12px] text-fg-3 sm:text-right">
            ~462 MiB · CPU · Apache-2.0
          </p>
        </div>
      </div>
    </section>
  );
}
