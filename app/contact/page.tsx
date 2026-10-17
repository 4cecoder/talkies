import Link from 'next/link';
import { Header } from '@/app/components/sections/Header';
import { Footer } from '@/app/components/sections/Footer';

const repository = 'https://github.com/4cecoder/talkies';

export default function ContactPage() {
  return (
    <div className="min-h-screen bg-bg text-fg">
      <Header />
      <main id="main" className="mx-auto max-w-3xl px-6 pb-24 pt-36">
        <p className="mb-3 text-sm font-medium font-mono uppercase tracking-[0.18em] text-accent">Community support</p>
        <h1 className="mb-5 display text-[2.6rem] font-semibold sm:text-6xl">Talkies is built in the open.</h1>
        <p className="mb-10 text-lg text-fg-3">Ask questions, report bugs, and suggest improvements on GitHub. Please don’t include recordings or private transcript content in public issues.</p>
        <div className="flex flex-wrap gap-4">
          <Link className="rounded-full bg-cta px-6 py-3 font-medium text-cta-fg hover:opacity-90" href={`${repository}/issues/new/choose`}>Open an issue</Link>
          <Link className="rounded-full border border-line-strong px-6 py-3 font-medium hover:bg-surface-2" href={`${repository}/discussions`}>Join discussions</Link>
        </div>
        <p className="mt-8 text-sm text-fg-3">The website does not have an account system or support backend. Email links, if provided in project materials, open in your own mail app.</p>
      </main>
      <Footer />
    </div>
  );
}
