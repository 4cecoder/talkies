export function Footer() {
  const currentYear = new Date().getFullYear();

  return (
    <footer className="border-t border-white/10 py-12 px-6">
      <div className="max-w-6xl mx-auto">
        <div className="flex flex-col md:flex-row justify-between items-center gap-6">
          <p className="text-sm text-neutral-500">
            <span className="bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text text-transparent font-semibold">
              © {currentYear} Talkies
            </span>
            {' '}• All rights reserved
          </p>

          <nav className="flex gap-6" aria-label="Footer navigation">
            <a
              href="#privacy"
              className="text-sm text-neutral-500 hover:text-purple-400 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-purple-500 rounded px-2 py-1"
            >
              Privacy
            </a>
            <a
              href="#terms"
              className="text-sm text-neutral-500 hover:text-purple-400 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-purple-500 rounded px-2 py-1"
            >
              Terms
            </a>
            <a
              href="#contact"
              className="text-sm text-neutral-500 hover:text-purple-400 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-purple-500 rounded px-2 py-1"
            >
              Contact
            </a>
          </nav>
        </div>
      </div>
    </footer>
  );
}
