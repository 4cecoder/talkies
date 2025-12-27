import { z } from 'zod';

// Sanitized string (prevents XSS)
export const sanitizedString = z
  .string()
  .transform((val) => {
    // Basic HTML sanitization
    return val
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#x27;')
      .trim();
  });

// URL validation with whitelist
export const trustedUrl = z
  .string()
  .url()
  .refine(
    (url) => {
      const parsed = new URL(url);
      const allowedHosts = [
        'localhost:3000',
        'talkies.app',
        'www.talkies.app',
      ];
      return allowedHosts.includes(parsed.host);
    },
    { message: 'URL not in allowed domains' }
  );
