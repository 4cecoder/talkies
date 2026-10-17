import { Cpu, Download, Keyboard, Mic, ShieldCheck, Sparkles } from 'lucide-react';
import { SectionHeading } from './SectionHeading';

const steps = [
  {
    icon: Download,
    title: 'Download a model once',
    body: 'You choose the model. Talkies fetches it over HTTPS and checks it against a pinned SHA-256 hash before using it.',
  },
  {
    icon: Mic,
    title: 'Hold your hotkey and talk',
    body: 'Audio is captured on your device and handed straight to the local engine. Nothing is streamed anywhere.',
  },
  {
    icon: Cpu,
    title: 'Recognised on your hardware',
    body: 'A local speech model turns audio into text. Optional S1-mini cleanup tidies punctuation and phrasing, also locally.',
  },
  {
    icon: Keyboard,
    title: 'Text lands at your cursor',
    body: 'Talkies types the result into the app you were using. Switch off Wi-Fi and it keeps working.',
  },
];

const never = ['No account or sign-in', 'No audio or transcript uploads', 'No analytics or tracking', 'No hosted speech service'];

function DeviceDiagram() {
  const nodes = [
    { icon: Mic, label: 'Microphone' },
    { icon: Cpu, label: 'Speech engine' },
    { icon: Sparkles, label: 'Cleanup' },
    { icon: Keyboard, label: 'Your cursor' },
  ];
  return (
    <figure className="card relative overflow-hidden p-5 sm:p-7" data-reveal>
      <div className="flex items-center justify-between gap-3">
        <p className="font-mono text-[11px] uppercase tracking-[0.18em] text-fg-3">Data flow</p>
        <p className="inline-flex items-center gap-1.5 rounded-full border border-line px-2.5 py-1 text-[11px] text-fg-2">
          <Download className="h-3 w-3" aria-hidden="true" />
          Model host · one-time download
        </p>
      </div>
      <div className="relative mt-5 rounded-2xl border border-dashed border-line-strong p-4 sm:p-5">
        <span className="absolute -top-3 left-4 rounded-full border border-line bg-bg px-2.5 py-0.5 text-[11px] font-medium uppercase tracking-wider text-accent">
          Your device
        </span>
        <ol className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          {nodes.map(({ icon: Icon, label }, index) => (
            <li key={label} className="relative flex flex-col items-center gap-2 rounded-xl border border-line bg-surface px-2 py-4 text-center">
              <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-gradient-to-br from-[#a855f7]/20 to-[#ec4899]/20 text-accent">
                <Icon className="h-4 w-4" aria-hidden="true" />
              </span>
              <span className="text-[13px] font-medium text-fg">{label}</span>
              {index < nodes.length - 1 && (
                <span className="absolute -right-2.5 top-1/2 hidden h-px w-2 bg-line-strong sm:block" aria-hidden="true" />
              )}
            </li>
          ))}
        </ol>
      </div>
      <figcaption className="mt-4 text-[13px] leading-relaxed text-fg-3">
        The network is used for the model download you start. After that, recording, recognition, cleanup and typing stay inside the dashed line.
      </figcaption>
    </figure>
  );
}

export function Privacy() {
  return (
    <section aria-labelledby="how-heading" id="how" className="relative py-16 sm:py-24">
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        <SectionHeading
          id="how-heading"
          eyebrow="How it works"
          title={
            <>
              Your voice never takes
              <br className="hidden sm:block" /> a round trip.
            </>
          }
          lede="Cloud dictation sends your audio to someone else's computer. There is no Talkies server to send it to: the whole job happens on your machine."
        />

        <ol className="mt-14 grid gap-px overflow-hidden rounded-[1.25rem] border border-line bg-line sm:grid-cols-2 lg:grid-cols-4">
          {steps.map(({ icon: Icon, title, body }, index) => (
            <li
              key={title}
              className="flex flex-col gap-4 bg-bg p-6 sm:p-7"
              data-reveal
              style={{ '--reveal-delay': `${index * 80}ms` } as React.CSSProperties}
            >
              <div className="flex items-center justify-between">
                <span className="flex h-10 w-10 items-center justify-center rounded-xl border border-line bg-surface text-fg">
                  <Icon className="h-[18px] w-[18px]" aria-hidden="true" />
                </span>
                <span className="font-mono text-[12px] text-fg-3" aria-hidden="true">
                  0{index + 1}
                </span>
              </div>
              <h3 className="text-[17px] font-semibold tracking-tight text-fg">{title}</h3>
              <p className="text-[15px] leading-relaxed text-fg-2">{body}</p>
            </li>
          ))}
        </ol>

        <div className="mt-6 grid gap-6 lg:grid-cols-[1.6fr_1fr]">
          <DeviceDiagram />
          <div className="card p-6 sm:p-7" data-reveal>
            <div className="flex items-center gap-2 text-fg">
              <ShieldCheck className="h-5 w-5 text-ok" aria-hidden="true" />
              <h3 className="text-[17px] font-semibold tracking-tight">Left out on purpose</h3>
            </div>
            <ul className="mt-5 space-y-3">
              {never.map((item) => (
                <li key={item} className="flex items-center gap-3 text-[15px] text-fg-2">
                  <span className="flex h-5 w-5 items-center justify-center rounded-full border border-line-strong text-[11px] text-fg-3" aria-hidden="true">
                    ✕
                  </span>
                  <span>{item}</span>
                </li>
              ))}
            </ul>
            <p className="mt-6 border-t border-line pt-5 text-[13px] leading-relaxed text-fg-3">
              No subscription, no billing, no trial timer. Your operating system&apos;s own sync or backup settings still apply.
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}
