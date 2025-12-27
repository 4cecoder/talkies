'use client';

import { ReactNode } from 'react';
import { useModalStore } from '@/app/store/modal-store';

interface AuthButtonProps {
  mode: 'login' | 'signup';
  children: ReactNode;
  className?: string;
}

export function AuthButton({ mode, children, className = '' }: AuthButtonProps) {
  const { openAuthModal } = useModalStore();

  return (
    <button onClick={() => openAuthModal(mode)} className={className}>
      {children}
    </button>
  );
}
