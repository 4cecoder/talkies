'use client';

import dynamic from 'next/dynamic';
import { useModalStore } from '@/app/store/modal-store';

// Lazy load modals for better code splitting
const AuthModal = dynamic(() => import('./AuthModal'), {
  ssr: false,
});

const CheckoutModal = dynamic(() => import('./CheckoutModal'), {
  ssr: false,
});

export function ModalManager() {
  const { activeModal, authMode, pricingTier, closeModal } = useModalStore();

  return (
    <>
      {activeModal === 'auth' && (
        <AuthModal
          isOpen={true}
          onClose={closeModal}
          initialMode={authMode}
        />
      )}
      {activeModal === 'checkout' && (
        <CheckoutModal
          isOpen={true}
          onClose={closeModal}
          plan={pricingTier}
        />
      )}
    </>
  );
}
