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
    onboardingCompleted: v.optional(v.boolean()),
    onboardingStep: v.optional(v.number()),
    selectedGoals: v.optional(v.array(v.string())),
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

  // Verification tokens (email verification, password reset)
  verificationTokens: defineTable({
    identifier: v.string(), // email or user ID
    token: v.string(),
    expires: v.number(), // timestamp
  })
    .index("by_identifier_and_token", ["identifier", "token"])
    .index("by_token", ["token"]),

  // User engagement statistics
  userStats: defineTable({
    userId: v.id("users"),
    totalWords: v.number(),
    totalMinutes: v.number(),
    totalTranscriptions: v.number(),
    languagesUsed: v.array(v.string()),
    longestStreak: v.number(),
    currentStreak: v.number(),
    lastActiveDate: v.string(), // YYYY-MM-DD
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_userId", ["userId"]),

  // Achievement system
  achievements: defineTable({
    userId: v.id("users"),
    achievementType: v.string(), // "word_count" | "streak" | "language" | "time"
    progress: v.number(),
    target: v.number(),
    unlockedAt: v.optional(v.number()),
    tier: v.string(), // "bronze" | "silver" | "gold" | "platinum"
  })
    .index("by_userId", ["userId"])
    .index("by_userId_and_type", ["userId", "achievementType"]),

  // User badges
  badges: defineTable({
    userId: v.id("users"),
    badgeId: v.string(),
    badgeName: v.string(),
    badgeDescription: v.string(),
    badgeIcon: v.string(),
    unlockedAt: v.number(),
    rarity: v.string(), // "common" | "rare" | "epic" | "legendary"
  })
    .index("by_userId", ["userId"]),

  // Referral system
  referrals: defineTable({
    referrerId: v.id("users"),
    refereeEmail: v.optional(v.string()),
    refereeUserId: v.optional(v.id("users")),
    referralCode: v.string(),
    status: v.string(), // "pending" | "completed" | "rewarded"
    rewardType: v.string(), // "free_month" | "discount" | "feature_unlock"
    createdAt: v.number(),
    completedAt: v.optional(v.number()),
  })
    .index("by_referrerId", ["referrerId"])
    .index("by_referralCode", ["referralCode"]),

  // Public showcase submissions
  showcaseSubmissions: defineTable({
    userId: v.id("users"),
    title: v.string(),
    description: v.string(),
    useCase: v.string(), // "podcast" | "blog" | "notes" | "creative" | "education"
    industry: v.string(),
    language: v.string(),
    wordCount: v.number(),
    transcriptPreview: v.string(), // First 500 chars
    imageUrl: v.optional(v.string()),
    featured: v.boolean(),
    likes: v.number(),
    views: v.number(),
    status: v.string(), // "pending" | "approved" | "rejected"
    submittedAt: v.number(),
  })
    .index("by_status", ["status"])
    .index("by_featured", ["featured"])
    .index("by_userId", ["userId"]),

  // Embed widget analytics
  embedAnalytics: defineTable({
    userId: v.id("users"),
    widgetType: v.string(),
    impressions: v.number(),
    clicks: v.number(),
    createdAt: v.number(),
  })
    .index("by_userId", ["userId"]),

  // User activation funnel tracking
  userActivations: defineTable({
    userId: v.id("users"),
    signupSource: v.string(), // "landing_demo" | "pricing" | "referral"
    platformSelected: v.optional(v.string()),
    appDownloaded: v.boolean(),
    firstTranscription: v.boolean(),
    onboardingCompleted: v.boolean(),
    createdAt: v.number(),
  })
    .index("by_userId", ["userId"]),

  // Contact form submissions
  contactSubmissions: defineTable({
    userId: v.optional(v.id("users")),
    email: v.string(),
    category: v.string(), // "general" | "bug" | "feature" | "billing"
    subject: v.string(),
    message: v.string(),
    status: v.string(), // "new" | "replied" | "resolved"
    createdAt: v.number(),
  })
    .index("by_status", ["status"])
    .index("by_userId", ["userId"]),

  // A/B testing variants
  abTestVariants: defineTable({
    userId: v.id("users"),
    testName: v.string(),
    variant: v.string(), // "A" | "B"
    converted: v.boolean(),
    convertedAt: v.optional(v.number()),
  })
    .index("by_testName", ["testName"])
    .index("by_userId", ["userId"]),

  // Analytics events
  events: defineTable({
    userId: v.optional(v.id("users")),
    sessionId: v.string(),
    eventName: v.string(),
    properties: v.optional(v.any()),
    timestamp: v.number(),
  })
    .index("by_eventName", ["eventName"])
    .index("by_sessionId", ["sessionId"]),
});
