import { mutation, query } from './_generated/server';
import { v } from 'convex/values';

// Generate a unique referral code
function generateReferralCode(userName: string): string {
  const randomPart = Math.random().toString(36).substring(2, 8).toUpperCase();
  const namePart = userName.substring(0, 4).toUpperCase().replace(/[^A-Z]/g, '');
  return `TALK-${namePart || 'USER'}-${randomPart}`;
}

// Generate or get referral code for user
export const generateReferralCode = mutation({
  args: { userId: v.id('users') },
  handler: async (ctx, args) => {
    // Check if user already has a referral code
    const existing = await ctx.db
      .query('referrals')
      .withIndex('by_referrerId', (q) => q.eq('referrerId', args.userId))
      .filter((q) => q.eq(q.field('status'), 'pending'))
      .first();

    if (existing) {
      return existing.referralCode;
    }

    // Get user name
    const user = await ctx.db.get(args.userId);
    if (!user) throw new Error('User not found');

    // Generate new code
    const code = generateReferralCode(user.name || user.email);

    // Create referral record
    await ctx.db.insert('referrals', {
      referrerId: args.userId,
      referralCode: code,
      status: 'pending',
      rewardType: 'free_month',
      createdAt: Date.now(),
    });

    return code;
  },
});

// Track referral click
export const trackReferralClick = mutation({
  args: { referralCode: v.string() },
  handler: async (ctx, args) => {
    const referral = await ctx.db
      .query('referrals')
      .withIndex('by_referralCode', (q) => q.eq('referralCode', args.referralCode))
      .first();

    if (!referral) {
      throw new Error('Invalid referral code');
    }

    // Track click in analytics
    await ctx.db.insert('events', {
      userId: referral.referrerId,
      sessionId: `referral-${Date.now()}`,
      eventName: 'referral_clicked',
      properties: { referralCode: args.referralCode },
      timestamp: Date.now(),
    });

    return referral.referrerId;
  },
});

// Complete referral (when referee signs up)
export const completeReferral = mutation({
  args: {
    referralCode: v.string(),
    refereeEmail: v.string(),
    refereeUserId: v.id('users'),
  },
  handler: async (ctx, args) => {
    const referral = await ctx.db
      .query('referrals')
      .withIndex('by_referralCode', (q) => q.eq('referralCode', args.referralCode))
      .first();

    if (!referral) {
      throw new Error('Invalid referral code');
    }

    // Update referral with referee info
    await ctx.db.patch(referral._id, {
      refereeEmail: args.refereeEmail,
      refereeUserId: args.refereeUserId,
      status: 'completed',
      completedAt: Date.now(),
    });

    // Track completion
    await ctx.db.insert('events', {
      userId: referral.referrerId,
      sessionId: `referral-${Date.now()}`,
      eventName: 'referral_completed',
      properties: {
        referralCode: args.referralCode,
        refereeEmail: args.refereeEmail,
      },
      timestamp: Date.now(),
    });

    return referral._id;
  },
});

// Get referral stats for a user
export const getReferralStats = query({
  args: { userId: v.id('users') },
  handler: async (ctx, args) => {
    const referrals = await ctx.db
      .query('referrals')
      .withIndex('by_referrerId', (q) => q.eq('referrerId', args.userId))
      .collect();

    const completed = referrals.filter((r) => r.status === 'completed').length;
    const pending = referrals.filter((r) => r.status === 'pending').length;
    const rewarded = referrals.filter((r) => r.status === 'rewarded').length;

    // Calculate rewards earned
    const rewardTiers = [
      { count: 1, reward: '1 month free Pro' },
      { count: 5, reward: 'Lifetime 20% discount' },
      { count: 10, reward: 'Custom vocabulary unlock' },
      { count: 25, reward: 'Lifetime Pro access' },
    ];

    const unlockedRewards = rewardTiers.filter((tier) => completed >= tier.count);
    const nextReward = rewardTiers.find((tier) => completed < tier.count);

    return {
      totalReferrals: referrals.length,
      completed,
      pending,
      rewarded,
      unlockedRewards,
      nextReward,
      referrals: referrals.map((r) => ({
        _id: r._id,
        code: r.referralCode,
        status: r.status,
        refereeEmail: r.refereeEmail,
        createdAt: r.createdAt,
        completedAt: r.completedAt,
      })),
    };
  },
});

// Claim referral reward
export const claimReward = mutation({
  args: {
    userId: v.id('users'),
    referralId: v.id('referrals'),
  },
  handler: async (ctx, args) => {
    const referral = await ctx.db.get(args.referralId);
    if (!referral) throw new Error('Referral not found');

    if (referral.referrerId !== args.userId) {
      throw new Error('Unauthorized');
    }

    if (referral.status !== 'completed') {
      throw new Error('Referral not completed');
    }

    // Mark as rewarded
    await ctx.db.patch(referral._id, {
      status: 'rewarded',
    });

    // Track reward claim
    await ctx.db.insert('events', {
      userId: args.userId,
      sessionId: `reward-${Date.now()}`,
      eventName: 'referral_reward_claimed',
      properties: {
        referralId: args.referralId,
        rewardType: referral.rewardType,
      },
      timestamp: Date.now(),
    });

    return {
      success: true,
      reward: referral.rewardType,
    };
  },
});

// Get leaderboard of top referrers
export const getTopReferrers = query({
  args: { limit: v.optional(v.number()) },
  handler: async (ctx, args) => {
    const limit = args.limit || 10;

    // Get all referrals
    const allReferrals = await ctx.db.query('referrals').collect();

    // Group by referrerId
    const referrerCounts: Record<string, number> = {};
    for (const referral of allReferrals) {
      if (referral.status === 'completed' || referral.status === 'rewarded') {
        const id = referral.referrerId as string;
        referrerCounts[id] = (referrerCounts[id] || 0) + 1;
      }
    }

    // Sort and get top referrers
    const sorted = Object.entries(referrerCounts)
      .sort(([, a], [, b]) => b - a)
      .slice(0, limit);

    // Get user details
    const leaderboard = await Promise.all(
      sorted.map(async ([userId, count]) => {
        const user = await ctx.db.get(userId as any);
        return {
          userId,
          userName: user?.name || 'Anonymous',
          referralCount: count,
        };
      })
    );

    return leaderboard;
  },
});
