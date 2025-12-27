'use client';

import { ReactNode } from 'react';
import { openAuthModal } from './ModalManager';

interface AuthButtonProps {
  mode: 'login' | 'signup';
  children: ReactNode;
  className?: string;
}

export function AuthButton({ mode, children, className = '' }: AuthButtonProps) {
  return (
    <button onClick={() => openAuthModal(mode)} className={className}>
      {children}
    </button>
  );
}
