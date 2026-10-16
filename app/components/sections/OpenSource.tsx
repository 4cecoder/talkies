import { ArrowUpRight, BookOpen, Bug, GitPullRequest, Map as MapIcon } from 'lucide-react';
import { CopyCommand } from '../CopyCommand';
import { SectionHeading } from './SectionHeading';
import { CONTRIBUTING_URL, GITHUB_REPO_URL, LICENSE_URL, NEW_ISSUE_URL, ROADMAP_URL } from '@/app/lib/site';

const links = [
  { href: GITHUB_REPO_URL, icon: BookOpen, title: 'Read the source', body: 'Swift, C#, Zig and Kotlin, one repository.' },
  { href: NEW_ISSUE_URL, icon: Bug, title: 'Report a bug', body: 'Leave recordings and private text out of public issues.' },
  { href: CONTRIBUTING_URL, icon: GitPullRequest, title: 'Contribute', body: 'How to propose changes and what review expects.' },
  { href: ROADMAP_URL, icon: MapIcon, title: 'Roadmap', body: 'Milestones and open work, tracked in GitHub Issues.' },
];

export function OpenSource() {
  return (
    <section aria-labelledby="oss-heading" id="open-source" className="relative py-16 sm:py-24">
      <div className="mx-auto grid max-w-6xl gap-12 px-4 sm:px-6 lg:grid-cols-[1fr_1.1fr] lg:items-center">
        <div>
          <SectionHeading
            id="oss-heading"
            eyebrow="Open source"
            title={
              <>
                MIT licensed.
                <br />
                <span className="text-fg-3">Read every line.</span>
              </>
            }
            lede="You shouldn't have to trust a privacy promise. Audit how audio is handled, build it yourself, or fork it. Model weights and third-party libraries keep their own licenses."
          />
          <div className="mt-8 max-w-lg" data-reveal>
            <CopyCommand command="git clone https://github.com/4cecoder/talkies" />
            <a
              href={LICENSE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="mt-4 inline-flex items-center gap-1 text-[14px] font-medium text-accent hover:underline"
            >
              Read the MIT License
              <ArrowUpRight className="h-3.5 w-3.5" aria-hidden="true" />
              <span className="sr-only"> (opens GitHub in a new tab)</span>
            </a>
          </div>
        </div>

        <ul className="grid gap-3 sm:grid-cols-2">
          {links.map(({ href, icon: Icon, title, body }, index) => (
            <li key={title} data-reveal style={{ '--reveal-delay': `${index * 70}ms` } as React.CSSProperties}>
              <a
                href={href}
                target="_blank"
                rel="noopener noreferrer"
                className="card group flex h-full flex-col gap-3 p-5 transition-colors hover:border-line-strong hover:bg-surface-2"
              >
                <div className="flex items-center justify-between">
                  <Icon className="h-5 w-5 text-accent" aria-hidden="true" />
                  <ArrowUpRight className="h-4 w-4 text-fg-3 transition-transform group-hover:-translate-y-0.5 group-hover:translate-x-0.5" aria-hidden="true" />
                </div>
                <span className="text-[16px] font-semibold tracking-tight text-fg">{title}</span>
                <span className="text-[14px] leading-relaxed text-fg-2">{body}</span>
                <span className="sr-only"> (opens GitHub in a new tab)</span>
              </a>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
