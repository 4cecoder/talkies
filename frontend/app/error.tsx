'use client';

import { useEffect } from 'react';
import { AlertTriangle } from './components/icons';
import { Button } from './components/ui/Button';

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    // Log error to error reporting service
    if (process.env.NODE_ENV === 'production') {
      // TODO: Send to error tracking service (Sentry, etc.)
      console.error('Page error:', error);
    }
  }, [error]);

  return (
    <div className="min-h-screen bg-[#0a0a0f] flex items-center justify-center p-6">
      <div className="max-w-md w-full rounded-3xl backdrop-blur-xl bg-white/5 border border-white/10 p-8 text-center">
        <AlertTriangle className="w-16 h-16 text-yellow-400 mx-auto mb-4" />
        <h2 className="text-2xl font-bold mb-2 text-white">
          Oops! Something went wrong
        </h2>
        <p className="text-neutral-400 mb-6">
          We encountered an unexpected error. Please try reloading the page.
        </p>
        {process.env.NODE_ENV === 'development' && (
          <pre className="text-left text-xs bg-black/50 p-4 rounded-lg mb-4 overflow-auto max-h-40 text-red-400">
            {error.message}
          </pre>
        )}
        <div className="flex gap-3">
          <Button variant="secondary" onClick={() => window.location.href = '/'}>
            Go Home
          </Button>
          <Button variant="gradient" onClick={reset}>
            Try Again
          </Button>
        </div>
      </div>
    </div>
  );
}
