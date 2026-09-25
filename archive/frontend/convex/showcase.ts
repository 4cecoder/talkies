import { mutation, query } from './_generated/server';
import { v } from 'convex/values';

// Submit showcase entry
export const submitShowcase = mutation({
  args: {
    userId: v.id('users'),
    title: v.string(),
    description: v.string(),
    useCase: v.string(),
    industry: v.string(),
    language: v.string(),
    wordCount: v.number(),
    transcriptPreview: v.string(),
    imageUrl: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    // Validation
    if (args.title.length < 3 || args.title.length > 100) {
      throw new Error('Title must be between 3 and 100 characters');
    }

    if (args.description.length < 10 || args.description.length > 500) {
      throw new Error('Description must be between 10 and 500 characters');
    }

    const validUseCases = ['podcast', 'blog', 'notes', 'creative', 'education', 'business'];
    if (!validUseCases.includes(args.useCase)) {
      throw new Error('Invalid use case');
    }

    // Insert showcase submission
    const submissionId = await ctx.db.insert('showcaseSubmissions', {
      userId: args.userId,
      title: args.title,
      description: args.description,
      useCase: args.useCase,
      industry: args.industry,
      language: args.language,
      wordCount: args.wordCount,
      transcriptPreview: args.transcriptPreview.substring(0, 500), // Ensure max 500 chars
      imageUrl: args.imageUrl,
      featured: false,
      likes: 0,
      views: 0,
      status: 'pending', // Requires moderation
      submittedAt: Date.now(),
    });

    // Track submission event
    await ctx.db.insert('events', {
      userId: args.userId,
      sessionId: `showcase-${Date.now()}`,
      eventName: 'showcase_submitted',
      properties: {
        submissionId,
        useCase: args.useCase,
        language: args.language,
      },
      timestamp: Date.now(),
    });

    return submissionId;
  },
});

// Get showcase gallery with filters
export const getShowcaseGallery = query({
  args: {
    useCase: v.optional(v.string()),
    industry: v.optional(v.string()),
    language: v.optional(v.string()),
    sortBy: v.optional(v.string()), // "trending" | "recent" | "most_liked" | "featured"
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const limit = args.limit || 20;

    // Start with approved submissions
    let query = ctx.db
      .query('showcaseSubmissions')
      .withIndex('by_status', (q) => q.eq('status', 'approved'));

    // Get all results
    let submissions = await query.collect();

    // Apply filters
    if (args.useCase) {
      submissions = submissions.filter((s) => s.useCase === args.useCase);
    }

    if (args.industry) {
      submissions = submissions.filter((s) => s.industry === args.industry);
    }

    if (args.language) {
      submissions = submissions.filter((s) => s.language === args.language);
    }

    // Sort
    if (args.sortBy === 'trending') {
      // Trending = likes + views in last 7 days
      submissions.sort((a, b) => {
        const scoreA = a.likes * 10 + a.views;
        const scoreB = b.likes * 10 + b.views;
        return scoreB - scoreA;
      });
    } else if (args.sortBy === 'most_liked') {
      submissions.sort((a, b) => b.likes - a.likes);
    } else if (args.sortBy === 'featured') {
      submissions = submissions.filter((s) => s.featured);
      submissions.sort((a, b) => b.submittedAt - a.submittedAt);
    } else {
      // Default: recent
      submissions.sort((a, b) => b.submittedAt - a.submittedAt);
    }

    // Limit results
    submissions = submissions.slice(0, limit);

    // Get user details for each submission
    const submissionsWithUsers = await Promise.all(
      submissions.map(async (submission) => {
        const user = await ctx.db.get(submission.userId);
        return {
          ...submission,
          userName: user?.name || 'Anonymous',
        };
      })
    );

    return submissionsWithUsers;
  },
});

// Get featured showcases (for homepage carousel)
export const getFeaturedShowcases = query({
  args: { limit: v.optional(v.number()) },
  handler: async (ctx, args) => {
    const limit = args.limit || 5;

    const featured = await ctx.db
      .query('showcaseSubmissions')
      .withIndex('by_featured', (q) => q.eq('featured', true))
      .filter((q) => q.eq(q.field('status'), 'approved'))
      .order('desc')
      .take(limit);

    // Get user details
    const featuredWithUsers = await Promise.all(
      featured.map(async (submission) => {
        const user = await ctx.db.get(submission.userId);
        return {
          ...submission,
          userName: user?.name || 'Anonymous',
        };
      })
    );

    return featuredWithUsers;
  },
});

// Like a showcase
export const likeShowcase = mutation({
  args: {
    userId: v.id('users'),
    showcaseId: v.id('showcaseSubmissions'),
  },
  handler: async (ctx, args) => {
    const showcase = await ctx.db.get(args.showcaseId);
    if (!showcase) throw new Error('Showcase not found');

    // Increment likes
    await ctx.db.patch(args.showcaseId, {
      likes: showcase.likes + 1,
    });

    // Track like event
    await ctx.db.insert('events', {
      userId: args.userId,
      sessionId: `like-${Date.now()}`,
      eventName: 'showcase_liked',
      properties: { showcaseId: args.showcaseId },
      timestamp: Date.now(),
    });

    return showcase.likes + 1;
  },
});

// Increment view count
export const incrementShowcaseView = mutation({
  args: { showcaseId: v.id('showcaseSubmissions') },
  handler: async (ctx, args) => {
    const showcase = await ctx.db.get(args.showcaseId);
    if (!showcase) throw new Error('Showcase not found');

    await ctx.db.patch(args.showcaseId, {
      views: showcase.views + 1,
    });

    return showcase.views + 1;
  },
});

// Moderate showcase (admin only)
export const moderateShowcase = mutation({
  args: {
    showcaseId: v.id('showcaseSubmissions'),
    status: v.string(), // "approved" | "rejected"
    featured: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    // TODO: Add admin authentication check
    const showcase = await ctx.db.get(args.showcaseId);
    if (!showcase) throw new Error('Showcase not found');

    const updates: Record<string, any> = { status: args.status };
    if (args.featured !== undefined) {
      updates.featured = args.featured;
    }

    await ctx.db.patch(args.showcaseId, updates);

    // Track moderation event
    await ctx.db.insert('events', {
      userId: showcase.userId,
      sessionId: `moderate-${Date.now()}`,
      eventName: 'showcase_moderated',
      properties: {
        showcaseId: args.showcaseId,
        status: args.status,
        featured: args.featured,
      },
      timestamp: Date.now(),
    });

    return { success: true };
  },
});

// Get user's own showcase submissions
export const getMyShowcases = query({
  args: { userId: v.id('users') },
  handler: async (ctx, args) => {
    return await ctx.db
      .query('showcaseSubmissions')
      .withIndex('by_userId', (q) => q.eq('userId', args.userId))
      .order('desc')
      .collect();
  },
});
