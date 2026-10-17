import Link from 'next/link';
import { LogoMark } from '../Logo';
import { CONTRIBUTING_URL, DISCUSSIONS_URL, GITHUB_REPO_URL, ISSUES_URL, LICENSE_URL, RELEASES_URL } from '@/app/lib/site';

type FooterLink = { label: string; href: string; external?: boolean };

const columns: { title: string; links: FooterLink[] }[] = [
  {
    title: 'Product',
    links: [
      { label: 'How it works', href: '/#how' },
      { label: 'Speech engines', href: '/#engines' },
      { label: 'Platforms', href: '/#platforms' },
      { label: 'Download', href: '/download' },
    ],
  },
  {
    title: 'Project',
    links: [
      { label: 'GitHub', href: GITHUB_REPO_URL, external: true },
      { label: 'Releases', href: RELEASES_URL, external: true },
      { label: 'Issues', href: ISSUES_URL, external: true },
      { label: 'Discussions', href: DISCUSSIONS_URL, external: true },
      { label: 'Contributing', href: CONTRIBUTING_URL, external: true },
    ],
  },
  {
    title: 'Legal',
    links: [
      { label: 'Privacy', href: '/legal/privacy' },
      { label: 'Terms', href: '/legal/terms' },
      { label: 'MIT License', href: LICENSE_URL, external: true },
      { label: 'Contact', href: '/contact' },
    ],
  },
];

const linkClass = 'text-[14px] text-fg-2 transition-colors hover:text-fg';

export function Footer() {
  const year = new Date().getFullYear();

  return (
    <footer className="border-t border-line">
      <div className="mx-auto grid max-w-6xl gap-10 px-4 py-14 sm:px-6 md:grid-cols-[1.4fr_repeat(3,1fr)]">
        <div>
          <Link href="/" className="inline-flex items-center gap-2.5 rounded-lg" aria-label="Talkies home">
            <LogoMark id="logo-footer" className="h-7 w-7" />
            <span className="text-[17px] font-semibold tracking-tight text-fg">Talkies</span>
          </Link>
          <p className="mt-4 max-w-xs text-[14px] leading-relaxed text-fg-3">
            Open-source, on-device dictation for macOS, Windows, Linux and Android.
          </p>
        </div>
        {columns.map((column) => (
          <nav key={column.title} aria-label={column.title}>
            <h2 className="font-mono text-[11px] font-medium uppercase tracking-[0.16em] text-fg-3">{column.title}</h2>
            <ul className="mt-4 space-y-2.5">
              {column.links.map((link) => (
                <li key={link.label}>
                  {link.external ? (
                    <a href={link.href} target="_blank" rel="noopener noreferrer" className={linkClass}>
                      {link.label}
                      <span className="sr-only"> (opens in a new tab)</span>
                    </a>
                  ) : (
                    <Link href={link.href} className={linkClass}>
                      {link.label}
                    </Link>
                  )}
                </li>
              ))}
            </ul>
          </nav>
        ))}
      </div>
      <div className="border-t border-line">
        <div className="mx-auto flex max-w-6xl flex-col gap-2 px-4 py-6 text-[13px] text-fg-3 sm:flex-row sm:items-center sm:justify-between sm:px-6">
          <p>© {year} Talkies contributors · MIT License</p>
          <p>This site has no analytics, trackers or external fonts.</p>
        </div>
      </div>
    </footer>
  );
}
