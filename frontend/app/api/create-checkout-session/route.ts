import { NextRequest, NextResponse } from 'next/server';
import { ConvexHttpClient } from 'convex/browser';
import { api } from '@/convex/_generated/api';
import { createCheckoutSchema } from '@/app/lib/validations/checkout';
import { auth } from '@/app/lib/auth';

// Initialize Convex client
const convex = new ConvexHttpClient(process.env.NEXT_PUBLIC_CONVEX_URL!);

export async function POST(req: NextRequest) {
  try {
    // CRITICAL: Verify authentication
    const session = await auth.api.getSession({ headers: req.headers });

    if (!session?.user?.id) {
      return NextResponse.json(
        { error: 'Authentication required' },
        { status: 401 }
      );
    }

    const body = await req.json();

    // Validate input with Zod
    const parsed = createCheckoutSchema.safeParse(body);

    if (!parsed.success) {
      return NextResponse.json(
        { error: 'Invalid input', details: parsed.error.issues },
        { status: 400 }
      );
    }

    // Call Convex action to create checkout session
    // The action handles Stripe API calls and validation
    const result = await convex.action(api.stripe.createCheckoutSession, {
      userId: session.user.id as any, // Cast to Convex ID type
      priceId: parsed.data.priceId,
      billingCycle: parsed.data.billingCycle,
    });

    return NextResponse.json(result);
  } catch (error) {
    console.error('Error creating checkout session:', error);
    return NextResponse.json(
      { error: 'Failed to create checkout session' },
      { status: 500 }
    );
  }
}
