'use client';

import { useEffect } from 'react';
import { AlertTriangle } from 'lucide-react';

export default function GlobalError({
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
      console.error('Global error:', error);
    }
  }, [error]);

  return (
    <html lang="en">
      <body style={{
        margin: 0,
        padding: 0,
        backgroundColor: '#0a0a0f',
        color: 'white',
        fontFamily: 'system-ui, -apple-system, sans-serif',
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}>
        <div style={{
          maxWidth: '500px',
          width: '100%',
          padding: '2rem',
          textAlign: 'center',
        }}>
          <AlertTriangle
            style={{
              width: '64px',
              height: '64px',
              color: '#facc15',
              margin: '0 auto 1rem',
            }}
          />
          <h2 style={{
            fontSize: '1.5rem',
            fontWeight: 'bold',
            marginBottom: '0.5rem',
          }}>
            Application Error
          </h2>
          <p style={{
            color: '#a3a3a3',
            marginBottom: '1.5rem',
          }}>
            We encountered a critical error. Please refresh the page.
          </p>
          {process.env.NODE_ENV === 'development' && (
            <pre style={{
              textAlign: 'left',
              fontSize: '0.75rem',
              backgroundColor: 'rgba(0,0,0,0.5)',
              padding: '1rem',
              borderRadius: '0.5rem',
              marginBottom: '1rem',
              overflow: 'auto',
              maxHeight: '160px',
              color: '#f87171',
            }}>
              {error.message}
            </pre>
          )}
          <button
            onClick={reset}
            style={{
              background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
              color: 'white',
              border: 'none',
              padding: '0.75rem 2rem',
              borderRadius: '0.75rem',
              cursor: 'pointer',
              fontSize: '1rem',
              fontWeight: '600',
            }}
          >
            Reload Application
          </button>
        </div>
      </body>
    </html>
  );
}
