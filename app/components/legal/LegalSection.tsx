'use client';

import { useState } from 'react';
import { ChevronDown, type LucideIcon } from 'lucide-react';

interface LegalSectionProps {
  icon: LucideIcon;
  title: string;
  tldr: string;
  children: React.ReactNode;
}

export function LegalSection({ icon: Icon, title, tldr, children }: LegalSectionProps) {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <div className="rounded-lg border border-white/10 bg-white/5 overflow-hidden backdrop-blur-xl">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="w-full flex items-start gap-4 p-6 text-left transition-colors hover:bg-white/5"
      >
        <div className="flex-shrink-0 mt-1">
          <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-gradient-to-r from-purple-500 to-pink-500">
            <Icon className="h-5 w-5 text-white" />
          </div>
        </div>

        <div className="flex-1 min-w-0">
          <h3 className="text-lg font-semibold text-white mb-2">{title}</h3>
          <p className="text-sm text-neutral-300">{tldr}</p>
        </div>

        <div className="flex-shrink-0">
          <ChevronDown
            className={`h-5 w-5 text-neutral-400 transition-transform ${
              isOpen ? 'rotate-180' : ''
            }`}
          />
        </div>
      </button>

      {isOpen && (
        <div className="px-6 pb-6 pt-2 text-sm text-neutral-300 space-y-4 border-t border-white/5">
          {children}
        </div>
      )}
    </div>
  );
}
