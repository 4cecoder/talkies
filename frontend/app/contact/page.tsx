import Link from 'next/link';
import { Header } from '@/app/components/sections/Header';
import { Footer } from '@/app/components/sections/Footer';

const repository = 'https://github.com/4cecoder/talkies';

export default function ContactPage() {
  return (
    <div className="min-h-screen bg-[#0a0a0f] text-white">
      <Header />
      <main className="mx-auto max-w-3xl px-6 pb-24 pt-36">
        <p className="mb-3 text-sm font-medium uppercase tracking-widest text-purple-300">Community support</p>
        <h1 className="mb-5 text-5xl font-bold">Talkies is built in the open.</h1>
        <p className="mb-10 text-lg text-neutral-400">Ask questions, report bugs, and suggest improvements on GitHub. Please don’t include recordings or private transcript content in public issues.</p>
        <div className="flex flex-wrap gap-4">
          <Link className="rounded-xl bg-purple-500 px-6 py-3 font-semibold hover:bg-purple-400" href={`${repository}/issues/new/choose`}>Open an issue</Link>
          <Link className="rounded-xl border border-white/15 px-6 py-3 font-semibold hover:bg-white/5" href={`${repository}/discussions`}>Join discussions</Link>
        </div>
        <p className="mt-8 text-sm text-neutral-500">The website does not have an account system or support backend. Email links, if provided in project materials, open in your own mail app.</p>
      </main>
      <Footer />
    </div>
  );
}
