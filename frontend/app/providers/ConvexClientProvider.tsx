"use client";

import { ReactNode, useMemo } from "react";
import { ConvexReactClient } from "convex/react";
import { ConvexBetterAuthProvider } from "@convex-dev/better-auth/react";
import { authClient } from "../lib/auth-client";

interface ConvexClientProviderProps {
  children: ReactNode;
}

export function ConvexClientProvider({ children }: ConvexClientProviderProps) {
  const convexClient = useMemo(() => {
    const convexUrl = process.env.NEXT_PUBLIC_CONVEX_URL;
    if (!convexUrl) {
      console.warn("NEXT_PUBLIC_CONVEX_URL is not set");
      return null;
    }
    return new ConvexReactClient(convexUrl);
  }, []);

  if (!convexClient) {
    // Render children without Convex provider during development without Convex URL
    return <>{children}</>;
  }

  return (
    <ConvexBetterAuthProvider client={convexClient} authClient={authClient}>
      {children}
    </ConvexBetterAuthProvider>
  );
}
