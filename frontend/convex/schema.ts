import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  // Users table
  users: defineTable({
    name: v.optional(v.string()),
    email: v.string(),
    emailVerified: v.optional(v.number()), // timestamp
    password: v.string(), // bcrypt hashed
    image: v.optional(v.string()),
    createdAt: v.number(), // timestamp
    updatedAt: v.number(), // timestamp
  })
    .index("by_email", ["email"]),

  // Sessions table (for BetterAuth)
  sessions: defineTable({
    userId: v.id("users"),
    sessionToken: v.string(),
    expires: v.number(), // timestamp
    createdAt: v.number(), // timestamp
  })
    .index("by_sessionToken", ["sessionToken"])
    .index("by_userId", ["userId"]),

  // Accounts table (for OAuth providers via BetterAuth)
  accounts: defineTable({
    userId: v.id("users"),
    type: v.string(), // "oauth" | "email" | "credentials"
    provider: v.string(),
    providerAccountId: v.string(),
    refresh_token: v.optional(v.string()),
    access_token: v.optional(v.string()),
    expires_at: v.optional(v.number()),
    token_type: v.optional(v.string()),
    scope: v.optional(v.string()),
    id_token: v.optional(v.string()),
    session_state: v.optional(v.string()),
  })
    .index("by_userId", ["userId"])
    .index("by_provider_and_providerAccountId", ["provider", "providerAccountId"]),

  // Subscriptions table (Stripe)
  subscriptions: defineTable({
    userId: v.id("users"),
    stripeCustomerId: v.string(),
    stripeSubscriptionId: v.string(),
    stripePriceId: v.string(),
    status: v.string(), // "active" | "canceled" | "incomplete" | "past_due" etc.
    currentPeriodEnd: v.number(), // timestamp
    createdAt: v.number(), // timestamp
    updatedAt: v.number(), // timestamp
  })
    .index("by_userId", ["userId"])
    .index("by_stripeCustomerId", ["stripeCustomerId"])
    .index("by_stripeSubscriptionId", ["stripeSubscriptionId"]),

  // Verification tokens (email verification, password reset)
  verificationTokens: defineTable({
    identifier: v.string(), // email or user ID
    token: v.string(),
    expires: v.number(), // timestamp
  })
    .index("by_identifier_and_token", ["identifier", "token"])
    .index("by_token", ["token"]),
});
