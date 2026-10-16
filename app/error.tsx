'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { AlertTriangle } from './components/icons';
import { Button } from './components/ui/Button';

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  const router = useRouter();

  useEffect(() => {
    // Log error to error reporting service
    if (process.env.NODE_ENV === 'production') {
      // TODO: Send to error tracking service (Sentry, etc.)
      console.error('Page error:', error);
    }
  }, [error]);

  return (
    <div className="min-h-screen bg-bg text-fg flex items-center justify-center p-6">
      <div className="max-w-md w-full card p-8 text-center">
        <AlertTriangle className="w-16 h-16 text-warn mx-auto mb-4" />
        <h2 className="text-2xl font-semibold tracking-tight mb-2 text-fg">
          This page failed to load
        </h2>
        <p className="text-fg-2 mb-6">
          Try again, or go back to the home page.
        </p>
        {process.env.NODE_ENV === 'development' && (
          <pre className="text-left text-xs bg-black/50 p-4 rounded-lg mb-4 overflow-auto max-h-40 text-red-400">
            {error.message}
          </pre>
        )}
        <div className="flex justify-center gap-3">
          <Button variant="secondary" onClick={() => router.push('/')}>
            Go Home
          </Button>
          <Button variant="primary" onClick={reset}>
            Try Again
          </Button>
        </div>
      </div>
    </div>
  );
}
