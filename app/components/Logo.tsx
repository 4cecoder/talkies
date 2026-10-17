interface LogoMarkProps {
  /** Unique gradient id; required when the mark appears more than once on a page. */
  id: string;
  className?: string;
}

/** The Talkies microphone mark from public/talkies-logo.svg, simplified for small sizes. */
export function LogoMark({ id, className }: LogoMarkProps) {
  return (
    <svg viewBox="0 0 32 32" fill="none" aria-hidden="true" className={className}>
      <defs>
        <linearGradient id={id} x1="0" y1="0" x2="32" y2="32" gradientUnits="userSpaceOnUse">
          <stop offset="0" stopColor="#a855f7" />
          <stop offset="1" stopColor="#ec4899" />
        </linearGradient>
      </defs>
      <rect x="11" y="3.5" width="10" height="15" rx="5" fill={`url(#${id})`} />
      <path d="M13.5 8h5M13.5 11h5M13.5 14h5" stroke="#fff" strokeOpacity=".55" strokeWidth="1.4" strokeLinecap="round" />
      <path d="M7.5 14.5a8.5 8.5 0 0 0 17 0M16 23v5M12 28h8" stroke={`url(#${id})`} strokeWidth="2" strokeLinecap="round" />
    </svg>
  );
}
