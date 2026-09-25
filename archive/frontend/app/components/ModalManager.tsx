'use client';

import dynamic from 'next/dynamic';
import { useModalStore } from '@/app/store/modal-store';

// Lazy load modals for better code splitting
const AuthModal = dynamic(() => import('./AuthModal'), {
  ssr: false,
});

export function ModalManager() {
  const { activeModal, authMode, closeModal } = useModalStore();

  return (
    <>
      {activeModal === 'auth' && (
        <AuthModal
          isOpen={true}
          onClose={closeModal}
          initialMode={authMode}
        />
      )}
    </>
  );
}
