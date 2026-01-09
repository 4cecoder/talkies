# Security Policy - Talkies Frontend

This document outlines the security measures implemented in the Talkies frontend application.

## Security Stack

### Authentication
- **BetterAuth** v1.4.9 - Modern, type-safe authentication
- **Session Management**: JWT sessions with 7-day expiration
- **Password Hashing**: Bcrypt with cost factor 12
- **Minimum Password Length**: 8 characters
- **Password Requirements**: Uppercase, lowercase, and number required

### State Management
- **Zustand** v5.0.9 - Type-safe global state with DevTools
- **Immer** v11.1.0 - Immutable state updates
- **No XSS Risk**: Replaced custom event system with Zustand stores

### Runtime Validation
- **Zod** v4.2.1 - Schema validation for all inputs/outputs
- **React Hook Form** v7.69.0 + Zod Resolver - Form validation
- **Server-side Validation**: All API endpoints validate inputs

### Database
- **Convex** v1.31.2 - Type-safe backend with real-time sync
- **Convex Schema**: Strongly typed database tables
- **No SQL Injection**: Convex ORM prevents injection attacks

### API Security
- **Server Actions**: Sensitive operations run server-side only
- **Authentication Required**: All mutations require valid session
- **Input Sanitization**: XSS protection via Zod transformations
- **Stripe Integration**: Webhook signature verification

### Data Fetching
- **TanStack Query** v5.90.12 - Server state management with caching
- **Automatic Retries**: Failed queries retry once
- **Stale Time**: 5-minute cache by default

## Security Headers

The application sets the following security headers via Next.js middleware:

```
X-DNS-Prefetch-Control: on
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Frame-Options: SAMEORIGIN
X-Content-Type-Options: nosniff
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: camera=(), microphone=(), geolocation=()
Content-Security-Policy: [configured for Stripe + Convex]
```

## OWASP Top 10 Mitigation

| Vulnerability | Mitigation |
|--------------|------------|
| **A01: Broken Access Control** | BetterAuth session verification on all protected routes, server-side authorization checks |
| **A02: Cryptographic Failures** | HTTPS enforced (HSTS), secrets in environment variables, password hashing with bcrypt |
| **A03: Injection** | Zod validation, Convex ORM (no SQL), input sanitization |
| **A04: Insecure Design** | Security-first architecture, server-side validation, principle of least privilege |
| **A05: Security Misconfiguration** | Security headers, CSP, X-Frame-Options, proper error handling |
| **A06: Vulnerable Components** | Regular dependency updates, minimal dependencies, Bun lockfile |
| **A07: Authentication Failures** | BetterAuth, session management, password requirements, rate limiting planned |
| **A08: Software & Data Integrity** | Stripe webhook signature verification, Convex schema validation |
| **A09: Logging & Monitoring** | Convex logs, error boundaries, webhook event logging |
| **A10: SSRF** | URL whitelist validation, trusted origins only |

## Authentication Flow

### Signup
1. Client submits form data (validated with Zod + React Hook Form)
2. Server validates input with `signupSchema`
3. Password hashed with bcrypt (cost factor 12)
4. User created in Convex database
5. BetterAuth creates session
6. JWT token set as HTTP-only cookie

### Login
1. Client submits credentials (validated with Zod)
2. Server validates input with `loginSchema`
3. User retrieved from Convex database
4. Password verified with bcrypt
5. BetterAuth creates session
6. JWT token set as HTTP-only cookie

### Session Verification
1. BetterAuth middleware checks JWT token
2. Session validated against database
3. User ID attached to request
4. Protected routes require valid session

## Stripe Integration Security

### Checkout
1. **Authentication Required**: Users must be logged in
2. **Input Validation**: Zod schema validates `priceId` and `billingCycle`
3. **Price Whitelist**: Only allowed price IDs accepted (prevents arbitrary pricing)
4. **Server-Side Only**: Stripe API calls happen in Convex actions
5. **Customer Linking**: Stripe customer ID linked to authenticated user

### Webhooks
1. **Signature Verification**: Stripe webhook signature verified
2. **Event Validation**: Zod schema validates event structure
3. **Idempotency**: Database upserts handle duplicate events
4. **Error Handling**: Failed webhooks logged and return error response

## Environment Variables

### Required Variables
```bash
# BetterAuth
BETTER_AUTH_SECRET=              # Generate with: openssl rand -base64 32
BETTER_AUTH_URL=                 # http://localhost:3000 in development

# Convex
NEXT_PUBLIC_CONVEX_URL=          # https://[deployment].convex.cloud
CONVEX_DEPLOYMENT=               # dev:[deployment-name]

# Stripe
NEXT_PUBLIC_STRIPE_KEY=          # pk_test_...
STRIPE_SECRET_KEY=               # sk_test_...
STRIPE_WEBHOOK_SECRET=           # whsec_...
STRIPE_PRICE_ID_PRO_MONTHLY=     # price_...
STRIPE_PRICE_ID_PRO_ANNUAL=      # price_...

# App
NEXT_PUBLIC_APP_URL=             # http://localhost:3000 in development
```

### Secret Management
- ✅ All secrets in `.env.local` (gitignored)
- ✅ `.env.example` template provided
- ✅ Secrets rotated after exposure
- ✅ No secrets in client-side code

## Security Best Practices

### Code
- ✅ TypeScript strict mode enabled
- ✅ No `any` types (except necessary Stripe type assertions)
- ✅ Input validation on client AND server
- ✅ Error boundaries prevent information leakage
- ✅ Security headers prevent common attacks

### Dependencies
- ✅ Minimal dependency footprint
- ✅ Regular updates via Bun
- ✅ No known vulnerabilities
- ✅ Lockfile committed

### Database
- ✅ Convex schema defines all tables
- ✅ Indexes for performance
- ✅ No raw queries
- ✅ Type-safe operations

## Known Limitations

### Rate Limiting
⚠️ **Not Yet Implemented** - No rate limiting on API routes
- Recommended: Implement Convex rate limiting or Upstash Redis
- Critical for preventing DoS attacks
- Should limit: login attempts, API calls, webhook processing

### Account Recovery
⚠️ **Not Yet Implemented** - No password reset flow
- Recommended: Email-based password reset
- Use verification tokens table
- Time-limited reset links

### Two-Factor Authentication
⚠️ **Not Implemented** - Optional 2FA not available
- Recommended: TOTP-based 2FA
- BetterAuth supports 2FA plugins

### Email Verification
⚠️ **Not Implemented** - Email verification optional
- Recommended: Require email verification for sensitive actions
- Use verification tokens table

## Incident Response

### Compromised Secrets
1. Immediately rotate affected secrets in Stripe/Vercel/Convex dashboards
2. Update `.env.local` with new secrets
3. Deploy to production
4. Invalidate all sessions (force re-login)

### Security Vulnerability
1. Assess severity and impact
2. Patch vulnerability immediately
3. Deploy fix to production
4. Notify affected users if data exposed
5. Document in security changelog

### Suspicious Activity
1. Review Convex logs for unusual patterns
2. Check Stripe dashboard for fraudulent transactions
3. Review user activity logs
4. Temporarily disable affected accounts if necessary

## Reporting Security Issues

**Please do not open public issues for security vulnerabilities.**

Email: security@talkies.app

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

We will respond within 48 hours and provide a fix timeline.

---

## Compliance

### Data Protection
- User passwords hashed (never stored in plaintext)
- JWTs stored in HTTP-only cookies (not localStorage)
- HTTPS enforced in production
- No sensitive data in client-side code

### Privacy
- Minimal data collection
- User data owned by user
- Can delete account (cascade deletes)
- No tracking cookies without consent

## Security Audit History

**2025-12-26**: Initial security maximization
- Implemented BetterAuth authentication
- Added Zod validation across all inputs
- Migrated to Zustand for type-safe state
- Added security headers middleware
- Implemented Stripe webhook verification
- Documented security practices

---

**Last Updated**: 2025-12-26
**Security Contact**: security@talkies.app
**Bug Bounty**: Not currently offered
