"use client";

import { ReactNode } from "react";
import { QueryProvider } from "./QueryProvider";
import { ConvexClientProvider } from "./ConvexClientProvider";

interface ProvidersProps {
  children: ReactNode;
}

export function Providers({ children }: ProvidersProps) {
  return (
    <QueryProvider>
      <ConvexClientProvider>{children}</ConvexClientProvider>
    </QueryProvider>
  );
}
