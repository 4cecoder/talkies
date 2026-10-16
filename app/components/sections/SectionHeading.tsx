interface SectionHeadingProps {
  id: string;
  eyebrow: string;
  title: React.ReactNode;
  lede?: React.ReactNode;
  align?: 'left' | 'center';
}

export function SectionHeading({ id, eyebrow, title, lede, align = 'left' }: SectionHeadingProps) {
  const centered = align === 'center';
  return (
    <div className={centered ? 'mx-auto max-w-3xl text-center' : 'max-w-3xl'} data-reveal>
      <p className="font-mono text-[12px] font-medium uppercase tracking-[0.18em] text-accent">{eyebrow}</p>
      <h2 id={id} className="display mt-4 text-balance text-[2.1rem] font-semibold text-fg sm:text-5xl">
        {title}
      </h2>
      {lede && <p className="mt-5 max-w-2xl text-[17px] leading-relaxed text-fg-2">{lede}</p>}
    </div>
  );
}
