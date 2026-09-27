import Link from 'next/link';
import { Header } from '@/app/components/sections/Header';
import { Footer } from '@/app/components/sections/Footer';

export default function PrivacyPolicyPage() {
  return (
    <div className="min-h-screen bg-[#0a0a0f] text-white">
      <Header />
      <main className="mx-auto max-w-3xl space-y-8 px-6 pb-24 pt-36">
        <header><p className="mb-3 text-sm font-medium uppercase tracking-widest text-purple-300">Privacy</p><h1 className="mb-4 text-5xl font-bold">Your voice stays yours.</h1><p className="text-neutral-400">Last updated: September 24, 2026</p></header>
        <section className="space-y-3"><h2 className="text-2xl font-semibold">The Talkies apps</h2><p className="text-neutral-300">Talkies is designed for local processing. Audio, transcripts, vocabulary, and preferences are processed and stored on your device. Talkies does not operate an account, analytics, advertising, or transcript upload service. The Windows app keeps bounded crash diagnostic logs locally; Talkies never uploads them. Optional language models must be downloaded before offline use; model downloads contact their configured hosting service and are not audio uploads.</p><p className="text-neutral-300">Your operating system and other applications may have their own diagnostics, sync, or backup behavior. Review their settings separately. You control local Talkies data and can remove it using the app or your platform’s uninstall/storage tools.</p></section>
        <section className="space-y-3"><h2 className="text-2xl font-semibold">This website</h2><p className="text-neutral-300">This static site is hosted with GitHub Pages. GitHub may process standard web request information such as IP address and user agent to operate and secure hosting. The site does not intentionally set analytics or advertising cookies, and Talkies does not receive GitHub’s hosting logs.</p><p className="text-neutral-300">Following links to GitHub, model hosts, or other sites subjects you to those services’ privacy practices. This policy may be updated as the project changes.</p></section>
        <p className="text-neutral-400">Questions or corrections? <Link className="text-purple-300 underline" href="/contact">Contact the community</Link>.</p>
      </main>
      <Footer />
    </div>
  );
}
