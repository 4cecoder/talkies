import { create } from 'zustand';
import { devtools } from 'zustand/middleware';
import { immer } from 'zustand/middleware/immer';

interface CheckoutState {
  isLoading: boolean;
  error: string | null;
  billingCycle: 'monthly' | 'annual';

  // Actions
  setBillingCycle: (cycle: 'monthly' | 'annual') => void;
  setLoading: (loading: boolean) => void;
  setError: (error: string | null) => void;
  reset: () => void;
}

export const useCheckoutStore = create<CheckoutState>()(
  devtools(
    immer((set) => ({
      isLoading: false,
      error: null,
      billingCycle: 'monthly',

      setBillingCycle: (cycle) => set((state) => {
        state.billingCycle = cycle;
      }),

      setLoading: (loading) => set((state) => {
        state.isLoading = loading;
      }),

      setError: (error) => set((state) => {
        state.error = error;
      }),

      reset: () => set({
        isLoading: false,
        error: null,
        billingCycle: 'monthly',
      }),
    })),
    { name: 'CheckoutStore' }
  )
);
