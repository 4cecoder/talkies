'use client';

import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ConvexProvider, ConvexReactClient } from 'convex/react';
import { ReactNode, useState } from 'react';

const convex = new ConvexReactClient(process.env.NEXT_PUBLIC_CONVEX_URL || '');

export function Providers({ children }: { children: ReactNode }) {
  // Create QueryClient inside component to avoid sharing state between requests
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            // Prevent refetch on window focus for better UX
            refetchOnWindowFocus: false,
            // Cache for 5 minutes
            staleTime: 5 * 60 * 1000,
            // Retry failed queries once
            retry: 1,
          },
        },
      })
  );

  return (
    <ConvexProvider client={convex}>
      <QueryClientProvider client={queryClient}>
        {children}
      </QueryClientProvider>
    </ConvexProvider>
  );
}
