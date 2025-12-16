"use client";

import { useState } from "react";
import { Button } from "../ui/Button";

interface HeaderProps {
  onSignInClick: () => void;
  onGetStartedClick: () => void;
}

export function Header({ onSignInClick, onGetStartedClick }: HeaderProps) {
  const [isScrolled, setIsScrolled] = useState(false);

  if (typeof window !== "undefined") {
    window.addEventListener("scroll", () => {
      setIsScrolled(window.scrollY > 20);
    });
  }

  const scrollToSection = (id: string) => {
    const element = document.getElementById(id);
    if (element) {
      element.scrollIntoView({ behavior: "smooth" });
    }
  };

  return (
    <header
      className={`fixed top-0 right-0 left-0 z-50 transition-all duration-300 ${
        isScrolled
          ? "border-b border-white/10 bg-[#0a0a0f]/80 backdrop-blur-xl"
          : ""
      }`}
    >
      <nav className="mx-auto max-w-7xl px-6 py-4" aria-label="Main navigation">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <svg
              width="32"
              height="32"
              viewBox="0 0 32 32"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
              className="transition-transform duration-300 hover:scale-110"
            >
              <defs>
                <linearGradient
                  id="micGrad"
                  x1="0%"
                  y1="0%"
                  x2="100%"
                  y2="100%"
                >
                  <stop
                    offset="0%"
                    style={{ stopColor: "#a855f7", stopOpacity: 1 }}
                  />
                  <stop
                    offset="100%"
                    style={{ stopColor: "#ec4899", stopOpacity: 1 }}
                  />
                </linearGradient>
              </defs>
              <rect
                x="11"
                y="4"
                width="10"
                height="14"
                rx="5"
                fill="url(#micGrad)"
              />
              <line
                x1="13"
                y1="8"
                x2="19"
                y2="8"
                stroke="#ffffff"
                strokeWidth="1.5"
                opacity="0.5"
                strokeLinecap="round"
              />
              <line
                x1="13"
                y1="11"
                x2="19"
                y2="11"
                stroke="#ffffff"
                strokeWidth="1.5"
                opacity="0.5"
                strokeLinecap="round"
              />
              <line
                x1="13"
                y1="14"
                x2="19"
                y2="14"
                stroke="#ffffff"
                strokeWidth="1.5"
                opacity="0.5"
                strokeLinecap="round"
              />
              <path
                d="M 16 18 L 16 22 M 12 22 L 20 22 M 14 22 L 14 26 M 18 26 L 14 26"
                stroke="url(#micGrad)"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
                fill="none"
              />
            </svg>
            <span className="bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text text-2xl font-bold text-transparent">
              Talkies
            </span>
          </div>

          <div className="hidden items-center gap-8 md:flex">
            <button
              onClick={() => scrollToSection("features")}
              className="rounded px-2 py-1 text-neutral-400 transition-colors hover:text-white focus-visible:ring-2 focus-visible:ring-purple-500 focus-visible:outline-none"
            >
              Features
            </button>
            <button
              onClick={() => scrollToSection("pricing")}
              className="rounded px-2 py-1 text-neutral-400 transition-colors hover:text-white focus-visible:ring-2 focus-visible:ring-purple-500 focus-visible:outline-none"
            >
              Pricing
            </button>
            <button
              onClick={() => scrollToSection("testimonials")}
              className="rounded px-2 py-1 text-neutral-400 transition-colors hover:text-white focus-visible:ring-2 focus-visible:ring-purple-500 focus-visible:outline-none"
            >
              Testimonials
            </button>
            <button
              onClick={() => scrollToSection("faq")}
              className="rounded px-2 py-1 text-neutral-400 transition-colors hover:text-white focus-visible:ring-2 focus-visible:ring-purple-500 focus-visible:outline-none"
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
