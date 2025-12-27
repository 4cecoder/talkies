import { v } from "convex/values";
import { action } from "./_generated/server";
import { api } from "./_generated/api";
import Stripe from "stripe";

// Helper to get Stripe instance (lazy initialization)
function getStripe() {
  if (!process.env.STRIPE_SECRET_KEY) {
    throw new Error("STRIPE_SECRET_KEY environment variable not set");
  }
  return new Stripe(process.env.STRIPE_SECRET_KEY, {
    apiVersion: "2025-12-15.clover",
  });
}

// Create Stripe checkout session
export const createCheckoutSession = action({
  args: {
    userId: v.id("users"),
    priceId: v.string(),
    billingCycle: v.union(v.literal("monthly"), v.literal("annual")),
  },
  handler: async (ctx, { userId, priceId }) => {
    // Verify priceId is in allowed list (prevent arbitrary pricing)
    const allowedPriceIds = [
      process.env.STRIPE_PRICE_ID_PRO_MONTHLY!,
      process.env.STRIPE_PRICE_ID_PRO_ANNUAL!,
    ];

    if (!allowedPriceIds.includes(priceId)) {
      throw new Error("Invalid price ID");
    }

    // Get user
    const user = await ctx.runQuery(api.users.getUser, { userId });
    if (!user) {
      throw new Error("User not found");
    }

    // Check if user already has a subscription
    const existingSubscription = await ctx.runQuery(
      api.subscriptions.getSubscriptionByUserId,
      { userId }
    );

    let customerId: string;

    if (existingSubscription) {
      // Use existing customer ID
      customerId = existingSubscription.stripeCustomerId;
    } else {
      // Create new Stripe customer
      const stripe = getStripe();
      const customer = await stripe.customers.create({
        email: user.email,
        name: user.name || undefined,
        metadata: { userId },
      });
      customerId = customer.id;
    }

    // Create checkout session
    const stripe = getStripe();
    const session = await stripe.checkout.sessions.create({
      customer: customerId,
      mode: "subscription",
      payment_method_types: ["card"],
      line_items: [{ price: priceId, quantity: 1 }],
      success_url: `${process.env.NEXT_PUBLIC_APP_URL}/dashboard?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${process.env.NEXT_PUBLIC_APP_URL}/?canceled=true`,
      metadata: {
        userId,
      },
    });

    return { url: session.url };
  },
});

// Handle Stripe webhook events
export const handleWebhook = action({
  args: {
    signature: v.string(),
    body: v.string(),
  },
  handler: async (ctx, { signature, body }) => {
    const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET!;
    const stripe = getStripe();

    // Verify webhook signature
    let event: Stripe.Event;
    try {
      event = stripe.webhooks.constructEvent(body, signature, webhookSecret);
    } catch (err) {
      throw new Error(`Webhook signature verification failed: ${err}`);
    }

    // Handle different event types
    switch (event.type) {
      case "checkout.session.completed": {
        const session = event.data.object as Stripe.Checkout.Session;
        const userId = session.metadata?.userId;

        if (!userId) {
          throw new Error("No userId in session metadata");
        }

        // Get subscription details
        const stripe = getStripe();
        const subscription = await stripe.subscriptions.retrieve(
          session.subscription as string
        );

        // Upsert subscription in database
        const sub = subscription as any; // Type assertion for Stripe Response
        await ctx.runMutation(api.subscriptions.upsertSubscription, {
          userId: userId as any, // Cast to Convex ID type
          stripeCustomerId: session.customer as string,
          stripeSubscriptionId: sub.id,
          stripePriceId: sub.items.data[0].price.id,
          status: sub.status,
          currentPeriodEnd: sub.current_period_end * 1000,
        });

        break;
      }

      case "customer.subscription.updated":
      case "customer.subscription.deleted": {
        const subscription = event.data.object as any; // Type assertion for Stripe Response

        await ctx.runMutation(api.subscriptions.updateSubscriptionStatus, {
          stripeSubscriptionId: subscription.id,
          status: subscription.status,
          currentPeriodEnd: subscription.current_period_end * 1000,
        });

        break;
      }

      default:
        console.log(`Unhandled event type: ${event.type}`);
    }

    return { received: true };
  },
});
