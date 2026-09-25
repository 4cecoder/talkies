import { mutation, query } from './_generated/server';
import { v } from 'convex/values';

// Submit a contact form
export const submitContactForm = mutation({
  args: {
    email: v.string(),
    category: v.string(),
    subject: v.string(),
    message: v.string(),
    userId: v.optional(v.id('users')),
  },
  handler: async (ctx, args) => {
    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(args.email)) {
      throw new Error('Invalid email address');
    }

    // Validate category
    const validCategories = ['general', 'bug', 'feature', 'billing'];
    if (!validCategories.includes(args.category)) {
      throw new Error('Invalid category');
    }

    // Validate subject and message length
    if (args.subject.length < 3 || args.subject.length > 200) {
      throw new Error('Subject must be between 3 and 200 characters');
    }

    if (args.message.length < 10 || args.message.length > 5000) {
      throw new Error('Message must be between 10 and 5000 characters');
    }

    // Insert into database
    const submissionId = await ctx.db.insert('contactSubmissions', {
      userId: args.userId,
      email: args.email,
      category: args.category,
      subject: args.subject,
      message: args.message,
      status: 'new',
      createdAt: Date.now(),
    });

    return submissionId;
  },
});

// Get user's own contact submissions (requires authentication)
export const getMyTickets = query({
  args: {},
  handler: async (ctx) => {
    // Check authentication
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      return [];
    }

    // Find user by email
    const user = await ctx.db
      .query('users')
      .filter((q) => q.eq(q.field('email'), identity.email))
      .first();

    if (!user) {
      return [];
    }

    // Get all submissions for this user
    const submissions = await ctx.db
      .query('contactSubmissions')
      .filter((q) => q.eq(q.field('userId'), user._id))
      .order('desc')
      .collect();

    return submissions;
  },
});
