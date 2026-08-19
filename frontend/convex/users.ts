import { v } from "convex/values";
import { mutation, query } from "./_generated/server";

// Get user by email
export const getUserByEmail = query({
  args: { email: v.string() },
  handler: async (ctx, { email }) => {
    return await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", email))
      .first();
  },
});

// Get user by ID
export const getUser = query({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    return await ctx.db.get(userId);
  },
});

// Create new user (called during signup)
export const createUser = mutation({
  args: {
    name: v.optional(v.string()),
    email: v.string(),
    password: v.string(), // Already hashed by BetterAuth
  },
  handler: async (ctx, args) => {
    const now = Date.now();

    const userId = await ctx.db.insert("users", {
      name: args.name,
      email: args.email,
      password: args.password,
      createdAt: now,
      updatedAt: now,
    });

    return userId;
  },
});

// Update user
export const updateUser = mutation({
  args: {
    userId: v.id("users"),
    name: v.optional(v.string()),
    email: v.optional(v.string()),
    emailVerified: v.optional(v.number()),
    image: v.optional(v.string()),
  },
  handler: async (ctx, { userId, ...updates }) => {
    await ctx.db.patch(userId, {
      ...updates,
      updatedAt: Date.now(),
    });

    return userId;
  },
});

// Delete user
export const deleteUser = mutation({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    // Delete user's sessions
    const sessions = await ctx.db
      .query("sessions")
      .withIndex("by_userId", (q) => q.eq("userId", userId))
      .collect();

    for (const session of sessions) {
      await ctx.db.delete(session._id);
    }

    // Delete user's accounts
    const accounts = await ctx.db
      .query("accounts")
      .withIndex("by_userId", (q) => q.eq("userId", userId))
      .collect();

    for (const account of accounts) {
      await ctx.db.delete(account._id);
    }

    // Delete user
    await ctx.db.delete(userId);
  },
});
