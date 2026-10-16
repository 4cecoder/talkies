import { Header } from './components/sections/Header';
import { Hero } from './components/sections/Hero';
import { Privacy } from './components/sections/Privacy';
import { Engines } from './components/sections/Engines';
import { Platforms } from './components/sections/Platforms';
import { OpenSource } from './components/sections/OpenSource';
import { FAQ } from './components/sections/FAQ';
import { FinalCta } from './components/sections/FinalCta';
import { Footer } from './components/sections/Footer';
import { RevealObserver } from './components/RevealObserver';

export default function Home() {
  return (
    <div className="relative min-h-screen overflow-x-clip bg-bg text-fg">
      <Header />
      <main id="main">
        <Hero />
        <Privacy />
        <Engines />
        <Platforms />
        <OpenSource />
        <FAQ />
        <FinalCta />
      </main>
      <Footer />
      <RevealObserver />
    </div>
  );
}
