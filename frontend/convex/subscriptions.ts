import { v } from "convex/values";
import { mutation, query } from "./_generated/server";

// Get subscription by user ID
export const getSubscriptionByUserId = query({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    return await ctx.db
      .query("subscriptions")
      .withIndex("by_userId", (q) => q.eq("userId", userId))
      .first();
  },
});

// Get subscription by Stripe customer ID
export const getSubscriptionByStripeCustomerId = query({
  args: { stripeCustomerId: v.string() },
  handler: async (ctx, { stripeCustomerId }) => {
    return await ctx.db
      .query("subscriptions")
      .withIndex("by_stripeCustomerId", (q) => q.eq("stripeCustomerId", stripeCustomerId))
      .first();
  },
});

// Get subscription by Stripe subscription ID
export const getSubscriptionByStripeSubscriptionId = query({
  args: { stripeSubscriptionId: v.string() },
  handler: async (ctx, { stripeSubscriptionId }) => {
    return await ctx.db
      .query("subscriptions")
      .withIndex("by_stripeSubscriptionId", (q) => q.eq("stripeSubscriptionId", stripeSubscriptionId))
      .first();
  },
});

// Create or update subscription
export const upsertSubscription = mutation({
  args: {
    userId: v.id("users"),
    stripeCustomerId: v.string(),
    stripeSubscriptionId: v.string(),
    stripePriceId: v.string(),
    status: v.string(),
    currentPeriodEnd: v.number(),
  },
  handler: async (ctx, args) => {
    const now = Date.now();

    // Check if subscription exists
    const existing = await ctx.db
      .query("subscriptions")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .first();

    if (existing) {
      // Update existing subscription
      await ctx.db.patch(existing._id, {
        stripeSubscriptionId: args.stripeSubscriptionId,
        stripePriceId: args.stripePriceId,
        status: args.status,
        currentPeriodEnd: args.currentPeriodEnd,
        updatedAt: now,
      });
      return existing._id;
    } else {
      // Create new subscription
      const subscriptionId = await ctx.db.insert("subscriptions", {
        userId: args.userId,
        stripeCustomerId: args.stripeCustomerId,
        stripeSubscriptionId: args.stripeSubscriptionId,
        stripePriceId: args.stripePriceId,
        status: args.status,
        currentPeriodEnd: args.currentPeriodEnd,
        createdAt: now,
        updatedAt: now,
      });
      return subscriptionId;
    }
  },
});

// Update subscription status
export const updateSubscriptionStatus = mutation({
  args: {
    stripeSubscriptionId: v.string(),
    status: v.string(),
    currentPeriodEnd: v.number(),
  },
  handler: async (ctx, { stripeSubscriptionId, status, currentPeriodEnd }) => {
    const subscription = await ctx.db
      .query("subscriptions")
      .withIndex("by_stripeSubscriptionId", (q) => q.eq("stripeSubscriptionId", stripeSubscriptionId))
      .first();

    if (!subscription) {
      throw new Error("Subscription not found");
    }

    await ctx.db.patch(subscription._id, {
      status,
      currentPeriodEnd,
      updatedAt: Date.now(),
    });

    return subscription._id;
  },
});

// Delete subscription
export const deleteSubscription = mutation({
  args: { stripeSubscriptionId: v.string() },
  handler: async (ctx, { stripeSubscriptionId }) => {
    const subscription = await ctx.db
      .query("subscriptions")
      .withIndex("by_stripeSubscriptionId", (q) => q.eq("stripeSubscriptionId", stripeSubscriptionId))
      .first();

    if (subscription) {
      await ctx.db.delete(subscription._id);
    }
  },
});
