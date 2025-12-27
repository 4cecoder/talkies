'use client';

import { useState, useEffect } from 'react';
import dynamic from 'next/dynamic';

// Lazy load modals for better code splitting
const AuthModal = dynamic(() => import('./AuthModal'), {
  ssr: false,
});

const CheckoutModal = dynamic(() => import('./CheckoutModal'), {
  ssr: false,
});

export function ModalManager() {
  const [authModalOpen, setAuthModalOpen] = useState(false);
  const [checkoutModalOpen, setCheckoutModalOpen] = useState(false);
  const [authMode, setAuthMode] = useState<'login' | 'signup'>('login');
  const [selectedPlan, setSelectedPlan] = useState<'free' | 'pro'>('pro');

  // Listen for custom events to open modals from Server Components
  useEffect(() => {
    const handleOpenAuth = (e: Event) => {
      const customEvent = e as CustomEvent;
      setAuthMode(customEvent.detail?.mode || 'login');
      setAuthModalOpen(true);
    };

    const handleOpenCheckout = (e: Event) => {
      const customEvent = e as CustomEvent;
      setSelectedPlan(customEvent.detail?.plan || 'pro');
      setCheckoutModalOpen(true);
    };

    window.addEventListener('openAuthModal', handleOpenAuth);
    window.addEventListener('openCheckoutModal', handleOpenCheckout);

    return () => {
      window.removeEventListener('openAuthModal', handleOpenAuth);
      window.removeEventListener('openCheckoutModal', handleOpenCheckout);
    };
  }, []);

  return (
    <>
      {authModalOpen && (
        <AuthModal
          isOpen={authModalOpen}
          onClose={() => setAuthModalOpen(false)}
          initialMode={authMode}
        />
      )}
      {checkoutModalOpen && (
        <CheckoutModal
          isOpen={checkoutModalOpen}
          onClose={() => setCheckoutModalOpen(false)}
          plan={selectedPlan}
        />
      )}
    </>
  );
}

// Helper functions to trigger modals from Server Components
export function openAuthModal(mode: 'login' | 'signup' = 'login') {
  if (typeof window !== 'undefined') {
    window.dispatchEvent(
      new CustomEvent('openAuthModal', { detail: { mode } })
    );
  }
}

export function openCheckoutModal(plan: 'free' | 'pro' = 'pro') {
  if (typeof window !== 'undefined') {
    window.dispatchEvent(
      new CustomEvent('openCheckoutModal', { detail: { plan } })
    );
  }
}
