'use client';

import Link from 'next/link';
import { Download } from 'lucide-react';
import { platforms } from '@/app/lib/site';
import { usePlatform } from '@/app/lib/usePlatform';

/** Primary hero CTA, labelled for the visitor's platform once the page hydrates. */
export function PrimaryDownload() {
  const detected = usePlatform();
  const match = platforms.find((p) => p.id === detected);
  const external = match !== undefined;
  const label = match ? match.cta : 'Download Talkies';
  const className =
    'group inline-flex h-12 min-w-[15.5rem] items-center justify-center gap-2 rounded-full bg-cta px-6 text-[15px] font-medium text-cta-fg shadow-[0_8px_30px_-8px_rgba(168,85,247,0.55)] transition-[opacity,transform,box-shadow] hover:shadow-[0_10px_40px_-6px_rgba(236,72,153,0.6)] active:scale-[0.98]';

  const content = (
    <>
      <Download className="h-4 w-4" aria-hidden="true" />
      {label}
    </>
  );

  if (!external) {
    return (
      <Link href="/download" className={className}>
        {content}
      </Link>
    );
  }

  return (
    <a href={match.href} target="_blank" rel="noopener noreferrer" className={className}>
      {content}
      <span className="sr-only"> (opens GitHub in a new tab)</span>
    </a>
  );
}
