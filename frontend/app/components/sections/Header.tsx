'use client';

import { useState, useEffect, useRef } from 'react';
import { Menu, X, Github, Download } from '../icons';

const GITHUB_REPO_URL = 'https://github.com/4cecoder/talkies';
const RELEASES_URL = `${GITHUB_REPO_URL}/releases/latest`;

export function Header() {
  const [isScrolled, setIsScrolled] = useState(false);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const mobileMenuRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const handleScroll = () => {
      setIsScrolled(window.scrollY > 20);
    };

    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  // Handle Escape key to close mobile menu
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && mobileMenuOpen) {
        setMobileMenuOpen(false);
      }
    };

    if (mobileMenuOpen) {
      document.addEventListener('keydown', handleEscape);
      document.body.style.overflow = 'hidden';
    }

    return () => {
      document.removeEventListener('keydown', handleEscape);
      document.body.style.overflow = 'unset';
    };
  }, [mobileMenuOpen]);

  // Focus trap for mobile menu
  useEffect(() => {
    if (!mobileMenuOpen || !mobileMenuRef.current) return;

    const focusableElements = mobileMenuRef.current.querySelectorAll(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    const firstElement = focusableElements[0] as HTMLElement;
    const lastElement = focusableElements[focusableElements.length - 1] as HTMLElement;

    const handleTab = (e: KeyboardEvent) => {
      if (e.key !== 'Tab') return;

      if (e.shiftKey) {
        if (document.activeElement === firstElement) {
          e.preventDefault();
          lastElement?.focus();
        }
      } else {
        if (document.activeElement === lastElement) {
          e.preventDefault();
          firstElement?.focus();
        }
      }
    };

    document.addEventListener('keydown', handleTab);
    firstElement?.focus();

    return () => {
      document.removeEventListener('keydown', handleTab);
    };
  }, [mobileMenuOpen]);

  const scrollToSection = (id: string) => {
    const element = document.getElementById(id);
    if (element) {
      element.scrollIntoView({ behavior: 'smooth' });
      setMobileMenuOpen(false);
    }
  };

  return (
    <header
      className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300 ${
        isScrolled ? 'bg-[#0a0a0f]/80 backdrop-blur-xl border-b border-white/10' : ''
      }`}
    >
      <nav className="max-w-7xl mx-auto px-6 py-4" aria-label="Main navigation">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <svg width="32" height="32" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg" className="transition-transform hover:scale-110 duration-300">
              <defs>
                <linearGradient id="micGrad" x1="0%" y1="0%" x2="100%" y2="100%">
                  <stop offset="0%" style={{stopColor:"#a855f7", stopOpacity:1}} />
                  <stop offset="100%" style={{stopColor:"#ec4899", stopOpacity:1}} />
                </linearGradient>
              </defs>
              <rect x="11" y="4" width="10" height="14" rx="5" fill="url(#micGrad)"/>
              <line x1="13" y1="8" x2="19" y2="8" stroke="#ffffff" strokeWidth="1.5" opacity="0.5" strokeLinecap="round"/>
              <line x1="13" y1="11" x2="19" y2="11" stroke="#ffffff" strokeWidth="1.5" opacity="0.5" strokeLinecap="round"/>
              <line x1="13" y1="14" x2="19" y2="14" stroke="#ffffff" strokeWidth="1.5" opacity="0.5" strokeLinecap="round"/>
              <path d="M 16 18 L 16 22 M 12 22 L 20 22 M 14 22 L 14 26 M 18 26 L 14 26"
                    stroke="url(#micGrad)"
                    strokeWidth="2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    fill="none"/>
            </svg>
            <span className="text-2xl font-bold bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text text-transparent">
              Talkies
            </span>
          </div>

          <div className="hidden md:flex items-center gap-8">
            <button
              onClick={() => scrollToSection('features')}
              className="text-neutral-400 hover:text-white transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-purple-500 rounded px-2 py-1"
            >
              Features
            </button>
            <button
              onClick={() => scrollToSection('faq')}
              className="text-neutral-400 hover:text-white transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-purple-500 rounded px-2 py-1"
            >
              FAQ
            </button>
            <a
              href="/contact"
              className="text-neutral-400 hover:text-white transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-purple-500 rounded px-2 py-1"
            >
              Contact
            </a>
          </div>

          <div className="hidden md:flex items-center gap-4">
            <a
              href={GITHUB_REPO_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2 text-neutral-400 hover:text-white transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-purple-500 rounded px-2 py-1"
            >
              <Github className="w-4 h-4" aria-hidden="true" />
              GitHub
            </a>
            <a
              href={RELEASES_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2 px-5 py-2.5 rounded-full font-semibold text-white bg-gradient-to-r from-purple-600 via-pink-600 to-blue-600 hover:opacity-90 transition-opacity focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-purple-500"
            >
              <Download className="w-4 h-4" aria-hidden="true" />
              Download
            </a>
          </div>

          {/* Mobile Menu Button */}
          <button
            onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
            className="md:hidden p-2 text-neutral-400 hover:text-white transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-purple-500 rounded"
            aria-label={mobileMenuOpen ? 'Close menu' : 'Open menu'}
            aria-expanded={mobileMenuOpen}
            aria-controls="mobile-menu"
          >
            {mobileMenuOpen ? (
              <X className="w-6 h-6" aria-hidden="true" />
            ) : (
              <Menu className="w-6 h-6" aria-hidden="true" />
            )}
          </button>
        </div>

        {/* Mobile Menu Drawer */}
        {mobileMenuOpen && (
          <>
            {/* Backdrop */}
            <div
              className="fixed inset-0 bg-black/60 backdrop-blur-sm z-40 md:hidden"
              onClick={() => setMobileMenuOpen(false)}
              aria-hidden="true"
            />

            {/* Mobile Menu */}
            <div
              ref={mobileMenuRef}
              id="mobile-menu"
              className="fixed top-0 right-0 bottom-0 w-[280px] bg-[#0a0a0f] border-l border-white/10 z-50 md:hidden animate-slide-in-right"
              role="dialog"
              aria-modal="true"
              aria-label="Mobile navigation"
            >
              <div className="flex flex-col h-full p-6">
                {/* Close Button */}
                <div className="flex justify-end mb-8">
                  <button
                    onClick={() => setMobileMenuOpen(false)}
                    className="p-2 text-neutral-400 hover:text-white transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-purple-500 rounded"
                    aria-label="Close menu"
                  >
                    <X className="w-6 h-6" />
                  </button>
                </div>

                {/* Navigation Links */}
                <nav className="flex flex-col gap-4 mb-8">
                  <button
                    onClick={() => scrollToSection('features')}
                    className="text-left text-lg text-neutral-300 hover:text-white transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-purple-500 rounded px-4 py-3 hover:bg-white/5"
                  >
                    Features
                  </button>
                  <button
                    onClick={() => scrollToSection('faq')}
                    className="text-left text-lg text-neutral-300 hover:text-white transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-purple-500 rounded px-4 py-3 hover:bg-white/5"
                  >
                    FAQ
                  </button>
                  <a
                    href="/contact"
                    className="text-left text-lg text-neutral-300 hover:text-white transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-purple-500 rounded px-4 py-3 hover:bg-white/5 block"
                  >
                    Contact
                  </a>
                </nav>

                {/* Links */}
                <div className="mt-auto flex flex-col gap-3">
                  <a
                    href={GITHUB_REPO_URL}
                    target="_blank"
                    rel="noopener noreferrer"
                    onClick={() => setMobileMenuOpen(false)}
                    className="inline-flex items-center justify-center gap-2 w-full px-4 py-3 rounded-full font-semibold text-neutral-300 border border-white/10 hover:bg-white/5 transition-colors"
                  >
                    <Github className="w-4 h-4" aria-hidden="true" />
                    GitHub
                  </a>
                  <a
                    href={RELEASES_URL}
                    target="_blank"
                    rel="noopener noreferrer"
                    onClick={() => setMobileMenuOpen(false)}
                    className="inline-flex items-center justify-center gap-2 w-full px-4 py-3 rounded-full font-semibold text-white bg-gradient-to-r from-purple-600 via-pink-600 to-blue-600 hover:opacity-90 transition-opacity"
                  >
                    <Download className="w-4 h-4" aria-hidden="true" />
                    Download
                  </a>
                </div>
              </div>
            </div>
          </>
        )}
      </nav>
    </header>
  );
}
