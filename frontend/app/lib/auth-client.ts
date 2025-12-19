"use client";

import { createAuthClient } from "better-auth/react";
import { convexClient } from "@convex-dev/better-auth/client/plugins";

export const authClient = createAuthClient({
  baseURL: process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000",
  plugins: [convexClient()],
});

// Export commonly used hooks and functions
export const {
  signIn,
  signUp,
  signOut,
  useSession,
  getSession,
} = authClient;
