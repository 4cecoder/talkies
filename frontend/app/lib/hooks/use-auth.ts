"use client";

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useAuthStore } from "../stores/auth-store";
import {
  signInAction,
  signUpAction,
  signOutAction,
  getSessionAction,
} from "../actions/auth-actions";
import type { SignInInput, SignUpInput } from "../validations/auth";
import { useEffect } from "react";

// Types for session data
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

interface SessionData {
  user: User;
  session: Session;
}

// Query keys for caching
export const authKeys = {
  all: ["auth"] as const,
  session: () => [...authKeys.all, "session"] as const,
  user: () => [...authKeys.all, "user"] as const,
};

// Hook for session management with TanStack Query
export function useSession() {
  const { login, logout, setLoading } = useAuthStore();

  const query = useQuery<SessionData>({
    queryKey: authKeys.session(),
    queryFn: async () => {
      const result = await getSessionAction();
      if (!result.success || !result.data) {
        throw new Error(result.error || "Not authenticated");
      }
      return result.data as SessionData;
    },
    retry: false,
    staleTime: 5 * 60 * 1000, // 5 minutes
    gcTime: 30 * 60 * 1000, // 30 minutes
  });

  // Sync with Zustand store
  useEffect(() => {
    if (query.isLoading) {
      setLoading(true);
    } else if (query.isError) {
      logout();
    } else if (query.data) {
      login(query.data.user, query.data.session);
    }
  }, [query.isLoading, query.isError, query.data, login, logout, setLoading]);

  return {
    ...query,
    user: query.data?.user,
    session: query.data?.session,
    isAuthenticated: !!query.data?.user,
  };
}

// Hook for sign in mutation
export function useSignIn() {
  const queryClient = useQueryClient();
  const { login } = useAuthStore();

  return useMutation({
    mutationFn: async (credentials: SignInInput) => {
      const result = await signInAction(credentials);
      if (!result.success) {
        throw new Error(result.error || "Sign in failed");
      }
      return result.data as SessionData | undefined;
    },
    onSuccess: (data) => {
      if (data?.user && data?.session) {
        login(data.user, data.session);
      }
      queryClient.invalidateQueries({ queryKey: authKeys.session() });
    },
  });
}

// Hook for sign up mutation
export function useSignUp() {
  const queryClient = useQueryClient();
  const { login } = useAuthStore();

  return useMutation({
    mutationFn: async (credentials: SignUpInput) => {
      const result = await signUpAction(credentials);
      if (!result.success) {
        throw new Error(result.error || "Sign up failed");
      }
      return result.data as SessionData | undefined;
    },
    onSuccess: (data) => {
      if (data?.user && data?.session) {
        login(data.user, data.session);
      }
      queryClient.invalidateQueries({ queryKey: authKeys.session() });
    },
  });
}

// Hook for sign out mutation
export function useSignOut() {
  const queryClient = useQueryClient();
  const { logout } = useAuthStore();

  return useMutation({
    mutationFn: async () => {
      const result = await signOutAction();
      if (!result.success) {
        throw new Error(result.error || "Sign out failed");
      }
      return result;
    },
    onSuccess: () => {
      logout();
      queryClient.invalidateQueries({ queryKey: authKeys.all });
      queryClient.removeQueries({ queryKey: authKeys.session() });
    },
  });
}

// Hook for accessing auth state from store
export function useAuth() {
  const store = useAuthStore();
  const { refetch } = useSession();

  return {
    ...store,
    refreshSession: refetch,
  };
}
