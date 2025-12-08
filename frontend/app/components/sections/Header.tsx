'use client';

import { useState } from 'react';
import { Button } from '../ui/Button';

interface HeaderProps {
  onSignInClick: () => void;
  onGetStartedClick: () => void;
}

export function Header({ onSignInClick, onGetStartedClick }: HeaderProps) {
  const [isScrolled, setIsScrolled] = useState(false);

  if (typeof window !== 'undefined') {
    window.addEventListener('scroll', () => {
      setIsScrolled(window.scrollY > 20);
    });
  }

  const scrollToSection = (id: string) => {
    const element = document.getElementById(id);
    if (element) {
      element.scrollIntoView({ behavior: 'smooth' });
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
          <div className="text-2xl font-bold">
            <span className="bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text text-transparent">
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
              onClick={() => scrollToSection('pricing')}
              className="text-neutral-400 hover:text-white transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-purple-500 rounded px-2 py-1"
            >
              Pricing
            </button>
            <button
              onClick={() => scrollToSection('testimonials')}
              className="text-neutral-400 hover:text-white transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-purple-500 rounded px-2 py-1"
            >
              Testimonials
            </button>
            <button
              onClick={() => scrollToSection('faq')}
              className="text-neutral-400 hover:text-white transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-purple-500 rounded px-2 py-1"
            >
              FAQ
            </button>
          </div>

          <div className="flex items-center gap-4">
            <Button variant="ghost" onClick={onSignInClick}>
              Sign In
            </Button>
            <Button variant="gradient" onClick={onGetStartedClick}>
              Get Started
            </Button>
          </div>
        </div>
      </nav>
    </header>
  );
}
