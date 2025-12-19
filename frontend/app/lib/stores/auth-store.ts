import { create } from "zustand";
import { persist, createJSONStorage } from "zustand/middleware";

interface User {
  id: string;
  email: string;
  name: string;
  emailVerified: boolean;
  createdAt: Date;
  updatedAt: Date;
}

interface Session {
  id: string;
  userId: string;
  expiresAt: Date;
}

interface AuthState {
  user: User | null;
  session: Session | null;
  isLoading: boolean;
  isAuthenticated: boolean;

  // Actions
  setUser: (user: User | null) => void;
  setSession: (session: Session | null) => void;
  setLoading: (isLoading: boolean) => void;
  login: (user: User, session: Session) => void;
  logout: () => void;
  reset: () => void;
}

const initialState = {
  user: null,
  session: null,
  isLoading: true,
  isAuthenticated: false,
};

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      ...initialState,

      setUser: (user) =>
        set({ user, isAuthenticated: !!user }),

      setSession: (session) =>
        set({ session }),

      setLoading: (isLoading) =>
        set({ isLoading }),

      login: (user, session) =>
        set({
          user,
          session,
          isLoading: false,
          isAuthenticated: true,
        }),

      logout: () =>
        set({
          user: null,
          session: null,
          isLoading: false,
          isAuthenticated: false,
        }),

      reset: () => set(initialState),
    }),
    {
      name: "talkies-auth-storage",
      storage: createJSONStorage(() => localStorage),
      partialize: (state) => ({
        user: state.user,
        session: state.session,
        isAuthenticated: state.isAuthenticated,
      }),
    }
  )
);
