import { Plus } from 'lucide-react';
import { SectionHeading } from './SectionHeading';
import { docsUrl, FIRST_RUN_URL, GITHUB_REPO_URL, ROADMAP_URL } from '@/app/lib/site';

const linkClass = 'font-medium text-fg underline decoration-line-strong underline-offset-4 hover:decoration-current';

function Ext({ href, children }: { href: string; children: React.ReactNode }) {
  return (
    <a href={href} target="_blank" rel="noopener noreferrer" className={linkClass}>
      {children}
    </a>
  );
}

const faqs: { question: string; answer: React.ReactNode }[] = [
  {
    question: 'Which platform should I use?',
    answer: (
      <>
        Use the one you type on. macOS, Windows and Linux have native builds on GitHub Releases; Linux is newer and still
        maturing. Android is in early access and is not yet distributed as a signed release. See the{' '}
        <Ext href={ROADMAP_URL}>roadmap</Ext> for current status.
      </>
    ),
  },
  {
    question: 'Is it really free?',
    answer: 'Yes. Talkies is MIT-licensed open source with no subscription, paywall, in-app purchase or account.',
  },
  {
    question: 'Does my audio leave my device?',
    answer:
      'No. Recognition runs locally with WhisperKit on macOS, Whisper.net on Windows and whisper.cpp on Linux and Android. Optional cleanup runs locally too. Audio and transcripts are not uploaded to any server.',
  },
  {
    question: 'Does it work offline?',
    answer: (
      <>
        Yes, after the one-time model download. The <Ext href={FIRST_RUN_URL}>first-run guide</Ext> walks through model
        setup, microphone permissions and text insertion.
      </>
    ),
  },
  {
    question: 'What is Phonon-2, and when does it arrive?',
    answer:
      'Phonon-2 is Fermion Research’s compressed build of NVIDIA Parakeet TDT, about 164 MB on Apple Silicon, for English. It is in progress as the new default English engine. Whisper remains available for other languages. There is no release date yet.',
  },
  {
    question: 'How do I build it from source?',
    answer: (
      <>
        Each platform has its own toolchain. Start with <Ext href={docsUrl('AGENTS.md')}>AGENTS.md</Ext> for commands, then the
        platform guide for <code className="font-mono text-[0.92em]">mac/</code>,{' '}
        <code className="font-mono text-[0.92em]">windows/</code>, <code className="font-mono text-[0.92em]">linux/</code> or{' '}
        <code className="font-mono text-[0.92em]">mobile/android/</code>.
      </>
    ),
  },
  {
    question: 'Where do I report bugs?',
    answer: (
      <>
        Open an issue on <Ext href={`${GITHUB_REPO_URL}/issues`}>GitHub</Ext>. Please leave recordings and private transcript text
        out of public reports.
      </>
    ),
  },
];

export function FAQ() {
  return (
    <section aria-labelledby="faq-heading" id="faq" className="relative py-16 sm:py-24">
      <div className="mx-auto grid max-w-6xl gap-12 px-4 sm:px-6 lg:grid-cols-[0.8fr_1.2fr]">
        <div className="lg:sticky lg:top-28 lg:self-start">
          <SectionHeading id="faq-heading" eyebrow="FAQ" title="Questions, answered plainly." />
        </div>
        <div className="divide-y divide-line border-y border-line" data-reveal>
          {faqs.map((faq) => (
            <details key={faq.question} className="group">
              <summary className="flex cursor-pointer list-none items-center justify-between gap-6 py-5 text-left text-[16px] font-medium text-fg [&::-webkit-details-marker]:hidden">
                {faq.question}
                <Plus className="h-4 w-4 shrink-0 text-fg-3 transition-transform duration-300 group-open:rotate-45" aria-hidden="true" />
              </summary>
              <div className="pb-6 pr-10 text-[15px] leading-relaxed text-fg-2">{faq.answer}</div>
            </details>
          ))}
        </div>
      </div>
    </section>
  );
}
