import Link from 'next/link';
import { Header } from '@/app/components/sections/Header';
import { Footer } from '@/app/components/sections/Footer';

export default function TermsPage() {
  return (
    <div className="min-h-screen bg-[#0a0a0f] text-white">
      <Header />
      <main className="mx-auto max-w-3xl space-y-8 px-6 pb-24 pt-36">
        <header><p className="mb-3 text-sm font-medium uppercase tracking-widest text-purple-300">Project terms</p><h1 className="mb-4 text-5xl font-bold">Free and open source.</h1><p className="text-neutral-400">Last updated: September 24, 2026</p></header>
        <section className="space-y-3"><h2 className="text-2xl font-semibold">Software license</h2><p className="text-neutral-300">Talkies project code is distributed under the MIT License, included in the repository. Third-party components and downloadable speech or language models may have separate licenses and terms; check their notices before use or redistribution.</p></section>
        <section className="space-y-3"><h2 className="text-2xl font-semibold">Your use</h2><p className="text-neutral-300">You are responsible for how you use Talkies and for obtaining any permissions required to record or transcribe people or content. Transcription and cleanup can make mistakes; review output before relying on or sharing it.</p></section>
        <section className="space-y-3"><h2 className="text-2xl font-semibold">No warranty</h2><p className="text-neutral-300">Talkies is provided “as is,” without warranties to the extent permitted by law. The project is community-maintained and does not promise availability, compatibility, or transcription accuracy.</p></section>
        <p className="text-neutral-400">See the <Link className="text-purple-300 underline" href="https://github.com/4cecoder/talkies/blob/master/LICENSE">MIT License</Link> and <Link className="text-purple-300 underline" href="/legal/privacy">Privacy Policy</Link>.</p>
      </main>
      <Footer />
    </div>
  );
}
