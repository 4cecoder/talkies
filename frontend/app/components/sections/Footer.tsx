"use client";

export function Footer() {
  const currentYear = new Date().getFullYear();

  return (
    <footer className="border-t border-white/10 px-6 py-12">
      <div className="mx-auto max-w-6xl">
        <div className="flex flex-col items-center justify-between gap-6 md:flex-row">
          <p className="text-sm text-neutral-500">
            <span className="bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text font-semibold text-transparent">
              © {currentYear} Talkies
            </span>{" "}
            • All rights reserved
          </p>

          <nav className="flex gap-6" aria-label="Footer navigation">
            <a
              href="#privacy"
              className="rounded px-2 py-1 text-sm text-neutral-500 transition-colors hover:text-purple-400 focus-visible:ring-2 focus-visible:ring-purple-500 focus-visible:outline-none"
            >
              Privacy
            </a>
            <a
              href="#terms"
              className="rounded px-2 py-1 text-sm text-neutral-500 transition-colors hover:text-purple-400 focus-visible:ring-2 focus-visible:ring-purple-500 focus-visible:outline-none"
            >
              Terms
            </a>
            <a
              href="#contact"
              className="rounded px-2 py-1 text-sm text-neutral-500 transition-colors hover:text-purple-400 focus-visible:ring-2 focus-visible:ring-purple-500 focus-visible:outline-none"
            >
              Contact
            </a>
          </nav>
        </div>
      </div>
    </footer>
  );
}
