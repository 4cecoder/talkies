import { create } from 'zustand';
import { devtools } from 'zustand/middleware';

type ModalType = 'auth' | null;
type AuthMode = 'login' | 'signup';

interface ModalState {
  activeModal: ModalType;
  authMode: AuthMode;

  // Actions (type-safe, no XSS risk)
  openAuthModal: (mode: AuthMode) => void;
  closeModal: () => void;
}

export const useModalStore = create<ModalState>()(
  devtools(
    (set) => ({
      activeModal: null,
      authMode: 'login',

      openAuthModal: (mode) => set({
        activeModal: 'auth',
        authMode: mode,
      }),

      closeModal: () => set({ activeModal: null }),
    }),
    { name: 'ModalStore' }
  )
);
