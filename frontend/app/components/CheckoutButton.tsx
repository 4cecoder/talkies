'use client';

import { ReactNode } from 'react';
import { openCheckoutModal } from './ModalManager';

interface CheckoutButtonProps {
  plan?: 'free' | 'pro';
  children: ReactNode;
  className?: string;
}

export function CheckoutButton({ plan = 'pro', children, className = '' }: CheckoutButtonProps) {
  return (
    <button onClick={() => openCheckoutModal(plan)} className={className}>
      {children}
    </button>
  );
}
