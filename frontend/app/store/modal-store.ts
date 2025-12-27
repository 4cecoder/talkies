import { create } from 'zustand';
import { devtools } from 'zustand/middleware';

type ModalType = 'auth' | 'checkout' | null;
type AuthMode = 'login' | 'signup';
type PricingTier = 'free' | 'pro';

interface ModalState {
  activeModal: ModalType;
  authMode: AuthMode;
  pricingTier: PricingTier;

  // Actions (type-safe, no XSS risk)
  openAuthModal: (mode: AuthMode) => void;
  openCheckoutModal: (tier: PricingTier) => void;
  closeModal: () => void;
}

export const useModalStore = create<ModalState>()(
  devtools(
    (set) => ({
      activeModal: null,
      authMode: 'login',
      pricingTier: 'free',

      openAuthModal: (mode) => set({
        activeModal: 'auth',
        authMode: mode,
      }),

      openCheckoutModal: (tier) => set({
        activeModal: 'checkout',
        pricingTier: tier,
      }),

      closeModal: () => set({ activeModal: null }),
    }),
    { name: 'ModalStore' }
  )
);
