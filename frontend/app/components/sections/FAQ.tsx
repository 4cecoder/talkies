const GITHUB_REPO_URL = 'https://github.com/4cecoder/talkies';

const faqs = [
  {
    question: "Which platform should I use?",
    answer: (
      <>
        macOS and Windows have the most complete, ready-to-use builds today — macOS needs
        Apple Silicon and macOS 15+, Windows needs 10/11 (64-bit). Linux has a working native
        build (X11 &amp; Wayland) but is newer and less polished. There was a Flutter mobile
        app in <code className="text-neutral-400">mobile/</code>, but it&apos;s deprecated and
        no longer built or maintained. See the platform picker above, or check{' '}
        <a href={`${GITHUB_REPO_URL}/blob/main/docs/ROADMAP.md`} target="_blank" rel="noopener noreferrer" className="underline hover:text-white">
          docs/ROADMAP.md
        </a>{' '}
        for the latest status.
      </>
    ),
    gradient: "from-green-300 to-emerald-300",
    hoverColor: "green-500"
  },
  {
    question: "Is this free?",
    answer: "Yes. Talkies is a free, open-source project with no subscriptions, no paywalls, and no in-app purchases. There's no account required to use the desktop apps.",
    gradient: "from-blue-300 to-cyan-300",
    hoverColor: "blue-500"
  },
  {
    question: "Does my data leave my device?",
    answer: "No. Transcription runs locally using WhisperKit (macOS), Whisper.net (Windows), or whisper.cpp (Linux) — your audio and transcripts are never uploaded to a server. The in-browser demo on this site works the same way: it runs a small model client-side in your browser.",
    gradient: "from-purple-300 to-pink-300",
    hoverColor: "purple-500"
  },
  {
    question: "Can I use it offline?",
    answer: "Yes, once a build is installed and its model is downloaded, the desktop apps work completely offline. No internet connection is required for transcription.",
    gradient: "from-orange-300 to-amber-300",
    hoverColor: "pink-500"
  },
  {
    question: "How do I build it from source?",
    answer: (
      <>
        Each platform has its own build commands — see the {' '}
        <a href={`${GITHUB_REPO_URL}/blob/main/AGENTS.md`} target="_blank" rel="noopener noreferrer" className="underline hover:text-white">
          AGENTS.md
        </a>{' '}
        reference and each platform&apos;s own README (<code className="text-neutral-400">mac/</code>,{' '}
        <code className="text-neutral-400">windows/</code>, <code className="text-neutral-400">linux/</code>,{' '}
        <code className="text-neutral-400">frontend/</code>) for the exact steps.
      </>
    ),
    gradient: "from-cyan-300 to-blue-300",
    hoverColor: "blue-500"
  },
  {
    question: "Where do I report bugs or contribute?",
    answer: (
      <>
        Open an issue or pull request on{' '}
        <a href={GITHUB_REPO_URL} target="_blank" rel="noopener noreferrer" className="underline hover:text-white">
          GitHub
        </a>
        . See <code className="text-neutral-400">CONTRIBUTING.md</code> at the repo root for how to get
        started, and <code className="text-neutral-400">docs/ROADMAP.md</code> for open work items.
      </>
    ),
    gradient: "from-pink-300 to-fuchsia-300",
    hoverColor: "purple-500"
  },
  {
    question: "What's the license?",
    answer: "MIT. See the LICENSE file at the repository root.",
    gradient: "from-yellow-300 to-orange-300",
    hoverColor: "green-500"
  }
];

export function FAQ() {
  return (
    <section id="faq" className="relative py-20 px-6">
      <div className="max-w-3xl mx-auto relative z-10">
        <h2 className="text-3xl md:text-4xl font-bold text-center mb-16">
          <span className="bg-gradient-to-r from-green-300 via-emerald-300 to-teal-300 bg-clip-text text-transparent">
            Frequently Asked Questions
          </span>
        </h2>

        <div className="space-y-6">
          {faqs.map((faq, index) => (
            <details key={index} className={`group p-6 rounded-2xl backdrop-blur-xl bg-white/5 border border-white/10 hover:border-${faq.hoverColor}/50 transition-all`}>
              <summary className={`font-semibold cursor-pointer text-lg bg-gradient-to-r ${faq.gradient} bg-clip-text text-transparent`}>
                {faq.question}
              </summary>
              <p className="mt-4 text-neutral-300 leading-relaxed">
                {faq.answer}
              </p>
            </details>
          ))}
        </div>
      </div>
    </section>
  );
}
