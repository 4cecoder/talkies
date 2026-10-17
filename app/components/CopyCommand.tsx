'use client';

import { useEffect, useRef, useState } from 'react';
import { Check, Copy } from 'lucide-react';

type CopyState = 'idle' | 'copied' | 'failed';

export function CopyCommand({ command }: { command: string }) {
  const [state, setState] = useState<CopyState>('idle');
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);

  useEffect(() => () => clearTimeout(timer.current), []);

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(command);
      setState('copied');
    } catch {
      setState('failed');
    }
    clearTimeout(timer.current);
    timer.current = setTimeout(() => setState('idle'), 2200);
  };

  const label = state === 'copied' ? 'Copied' : state === 'failed' ? 'Copy failed. Select the text instead.' : 'Copy command';

  return (
    <div className="flex items-center gap-3 rounded-xl border border-line bg-elev/70 py-2 pl-4 pr-2 font-mono text-[13px] text-fg-2 shadow-[var(--shadow-card)]">
      <span className="select-none text-fg-3" aria-hidden="true">$</span>
      <code className="min-w-0 flex-1 overflow-x-auto whitespace-nowrap py-1 text-fg">{command}</code>
      <button
        type="button"
        onClick={copy}
        aria-label={label}
        title={label}
        className="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-lg text-fg-3 transition-colors hover:bg-surface-2 hover:text-fg"
      >
        {state === 'copied' ? <Check className="h-4 w-4 text-ok" aria-hidden="true" /> : <Copy className="h-4 w-4" aria-hidden="true" />}
      </button>
      <span className="sr-only" role="status" aria-live="polite">
        {state === 'copied' ? 'Command copied to clipboard' : state === 'failed' ? 'Could not copy. Select the command and copy it manually.' : ''}
      </span>
    </div>
  );
}
