'use client';

import { ReactNode } from 'react';
import { useModalStore } from '@/app/store/modal-store';

interface CheckoutButtonProps {
  plan?: 'free' | 'pro';
  children: ReactNode;
  className?: string;
}

export function CheckoutButton({ plan = 'pro', children, className = '' }: CheckoutButtonProps) {
  const { openCheckoutModal } = useModalStore();

  return (
    <button onClick={() => openCheckoutModal(plan)} className={className}>
      {children}
    </button>
  );
}
