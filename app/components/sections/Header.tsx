'use client';

import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { Menu, X, Github, ArrowRight } from '../icons';
import { LogoMark } from '../Logo';
import { ThemeToggle } from '../ThemeToggle';
import { GITHUB_REPO_URL } from '@/app/lib/site';

const navItems = [
  { href: '/#how', label: 'How it works' },
  { href: '/#engines', label: 'Engines' },
  { href: '/#platforms', label: 'Platforms' },
  { href: '/#open-source', label: 'Open source' },
];

export function Header() {
  const [isScrolled, setIsScrolled] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const sheetRef = useRef<HTMLDivElement>(null);
  const toggleRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    const onScroll = () => setIsScrolled(window.scrollY > 8);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  useEffect(() => {
    if (!menuOpen) return;
    const sheet = sheetRef.current;
    const toggle = toggleRef.current;
    const focusables = () =>
      Array.from(sheet?.querySelectorAll<HTMLElement>('a[href], button:not([disabled])') ?? []);

    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setMenuOpen(false);
        return;
      }
      if (event.key !== 'Tab') return;
      const items = [toggle, ...focusables()].filter(Boolean) as HTMLElement[];
      const first = items[0];
      const last = items[items.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };

    const mql = window.matchMedia('(min-width: 768px)');
    const onWide = () => mql.matches && setMenuOpen(false);

    document.addEventListener('keydown', onKeyDown);
    mql.addEventListener('change', onWide);
    document.body.style.overflow = 'hidden';
    focusables()[0]?.focus();

    return () => {
      document.removeEventListener('keydown', onKeyDown);
      mql.removeEventListener('change', onWide);
      document.body.style.overflow = '';
      toggle?.focus();
    };
  }, [menuOpen]);

  const close = () => setMenuOpen(false);
  const solid = isScrolled || menuOpen;

  return (
    <header
      className={`fixed inset-x-0 top-0 z-50 transition-[background-color,border-color,backdrop-filter] duration-300 ${
        solid ? 'border-b border-line bg-bg/75 backdrop-blur-xl backdrop-saturate-150' : 'border-b border-transparent'
      }`}
    >
      <a
        href="#main"
        className="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-3 focus:z-[60] focus:rounded-lg focus:bg-cta focus:px-4 focus:py-2 focus:text-sm focus:font-medium focus:text-cta-fg"
      >
        Skip to content
      </a>
      <nav className="mx-auto flex h-16 max-w-6xl items-center justify-between gap-4 px-4 sm:px-6" aria-label="Main">
        <Link href="/" className="flex items-center gap-2.5 rounded-lg" aria-label="Talkies home">
          <LogoMark id="logo-header" className="h-7 w-7" />
          <span className="text-[17px] font-semibold tracking-tight text-fg">Talkies</span>
        </Link>

        <ul className="hidden items-center gap-1 md:flex">
          {navItems.map((item) => (
            <li key={item.href}>
              <Link
                href={item.href}
                className="rounded-full px-3 py-1.5 text-sm text-fg-2 transition-colors hover:bg-surface-2 hover:text-fg"
              >
                {item.label}
              </Link>
            </li>
          ))}
        </ul>

        <div className="flex items-center gap-1.5">
          <ThemeToggle />
          <a
            href={GITHUB_REPO_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="hidden h-9 w-9 items-center justify-center rounded-full text-fg-2 transition-colors hover:bg-surface-2 hover:text-fg sm:inline-flex"
            aria-label="Talkies on GitHub (opens in a new tab)"
          >
            <Github className="h-4 w-4" aria-hidden="true" />
          </a>
          <Link
            href="/download"
            className="group ml-1 hidden items-center gap-1.5 rounded-full bg-cta px-4 py-2 text-sm font-medium text-cta-fg transition-[opacity,transform] hover:opacity-90 active:scale-[0.98] sm:inline-flex"
          >
            Download
            <ArrowRight className="h-3.5 w-3.5 transition-transform group-hover:translate-x-0.5" aria-hidden="true" />
          </Link>
          <button
            ref={toggleRef}
            type="button"
            onClick={() => setMenuOpen((open) => !open)}
            className="inline-flex h-9 w-9 items-center justify-center rounded-full text-fg-2 transition-colors hover:bg-surface-2 hover:text-fg md:hidden"
            aria-label={menuOpen ? 'Close menu' : 'Open menu'}
            aria-expanded={menuOpen}
            aria-controls="mobile-menu"
          >
            {menuOpen ? <X className="h-5 w-5" aria-hidden="true" /> : <Menu className="h-5 w-5" aria-hidden="true" />}
          </button>
        </div>
      </nav>

      {menuOpen && (
        <>
          <div className="fixed inset-0 top-16 z-40 bg-bg/60 backdrop-blur-sm md:hidden" onClick={close} aria-hidden="true" />
          <div
            ref={sheetRef}
            id="mobile-menu"
            className="animate-sheet-in absolute inset-x-0 top-16 z-50 border-b border-line bg-bg px-4 pb-6 pt-2 md:hidden"
          >
            <nav aria-label="Mobile">
              <ul className="flex flex-col">
                {navItems.map((item) => (
                  <li key={item.href}>
                    <Link
                      href={item.href}
                      onClick={close}
                      className="block rounded-xl px-3 py-3 text-base text-fg transition-colors hover:bg-surface-2"
                    >
                      {item.label}
                    </Link>
                  </li>
                ))}
              </ul>
              <div className="mt-4 grid grid-cols-2 gap-2">
                <a
                  href={GITHUB_REPO_URL}
                  target="_blank"
                  rel="noopener noreferrer"
                  onClick={close}
                  className="inline-flex items-center justify-center gap-2 rounded-full border border-line-strong px-4 py-3 text-sm font-medium text-fg"
                >
                  <Github className="h-4 w-4" aria-hidden="true" />
                  GitHub
                </a>
                <Link
                  href="/download"
                  onClick={close}
                  className="inline-flex items-center justify-center gap-2 rounded-full bg-cta px-4 py-3 text-sm font-medium text-cta-fg"
                >
                  Download
                </Link>
              </div>
            </nav>
          </div>
        </>
      )}
    </header>
  );
}
