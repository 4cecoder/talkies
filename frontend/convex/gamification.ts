import { mutation, query } from './_generated/server';
import { v } from 'convex/values';

// Achievement definitions
const ACHIEVEMENT_DEFINITIONS = {
  // Word count milestones
  words_100: { target: 100, tier: 'bronze', name: 'First Steps', description: '100 words transcribed' },
  words_1000: { target: 1000, tier: 'bronze', name: 'Getting Started', description: '1,000 words transcribed' },
  words_10000: { target: 10000, tier: 'silver', name: 'Prolific Writer', description: '10,000 words transcribed' },
  words_50000: { target: 50000, tier: 'gold', name: 'Word Master', description: '50,000 words transcribed' },
  words_100000: { target: 100000, tier: 'gold', name: 'Century Club', description: '100,000 words transcribed' },
  words_500000: { target: 500000, tier: 'platinum', name: 'Half Million', description: '500,000 words transcribed' },
  words_1000000: { target: 1000000, tier: 'platinum', name: 'Million Word Club', description: '1,000,000 words transcribed' },

  // Language milestones
  languages_2: { target: 2, tier: 'bronze', name: 'Bilingual', description: 'Used 2 languages' },
  languages_5: { target: 5, tier: 'silver', name: 'Polyglot', description: 'Used 5 languages' },
  languages_10: { target: 10, tier: 'gold', name: 'Language Master', description: 'Used 10 languages' },
  languages_20: { target: 20, tier: 'platinum', name: 'Global Communicator', description: 'Used 20 languages' },

  // Streak milestones
  streak_7: { target: 7, tier: 'bronze', name: 'Week Warrior', description: '7 day streak' },
  streak_30: { target: 30, tier: 'silver', name: 'Monthly Commitment', description: '30 day streak' },
  streak_100: { target: 100, tier: 'gold', name: 'Centurion', description: '100 day streak' },
  streak_365: { target: 365, tier: 'platinum', name: 'Year of Voice', description: '365 day streak' },

  // Time milestones (in hours)
  time_1: { target: 1, tier: 'bronze', name: 'First Hour', description: '1 hour transcribed' },
  time_10: { target: 10, tier: 'silver', name: 'Ten Hours', description: '10 hours transcribed' },
  time_50: { target: 50, tier: 'gold', name: 'Fifty Hours', description: '50 hours transcribed' },
  time_100: { target: 100, tier: 'gold', name: 'Century of Time', description: '100 hours transcribed' },
  time_500: { target: 500, tier: 'platinum', name: 'Time Master', description: '500 hours transcribed' },
};

// Increment word count and check achievements
export const incrementWordCount = mutation({
  args: {
    userId: v.id('users'),
    words: v.number(),
    minutes: v.number(),
    language: v.string(),
  },
  handler: async (ctx, args) => {
    // Get or create user stats
    let stats = await ctx.db
      .query('userStats')
      .withIndex('by_userId', (q) => q.eq('userId', args.userId))
      .first();

    const today = new Date().toISOString().split('T')[0];

    if (!stats) {
      // Create new stats
      const newStats = {
        userId: args.userId,
        totalWords: args.words,
        totalMinutes: args.minutes,
        totalTranscriptions: 1,
        languagesUsed: [args.language],
        longestStreak: 1,
        currentStreak: 1,
        lastActiveDate: today,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      };
      const statsId = await ctx.db.insert('userStats', newStats);
      stats = await ctx.db.get(statsId);
      if (!stats) throw new Error('Failed to create user stats');
    } else {
      // Update existing stats
      const updatedLanguages = stats.languagesUsed.includes(args.language)
        ? stats.languagesUsed
        : [...stats.languagesUsed, args.language];

      // Calculate streak
      const lastDate = new Date(stats.lastActiveDate);
      const todayDate = new Date(today);
      const daysDiff = Math.floor((todayDate.getTime() - lastDate.getTime()) / (1000 * 60 * 60 * 24));

      let currentStreak = stats.currentStreak;
      if (daysDiff === 1) {
        currentStreak += 1;
      } else if (daysDiff > 1) {
        currentStreak = 1;
      }

      const longestStreak = Math.max(stats.longestStreak, currentStreak);

      await ctx.db.patch(stats._id, {
        totalWords: stats.totalWords + args.words,
        totalMinutes: stats.totalMinutes + args.minutes,
        totalTranscriptions: stats.totalTranscriptions + 1,
        languagesUsed: updatedLanguages,
        currentStreak,
        longestStreak,
        lastActiveDate: today,
        updatedAt: Date.now(),
      });
    }

    // Check and unlock achievements
    await checkAndUnlockAchievements(ctx, args.userId);
  },
});

// Check and unlock achievements (internal helper)
async function checkAndUnlockAchievements(ctx: any, userId: any) {
  const stats = await ctx.db
    .query('userStats')
    .withIndex('by_userId', (q: any) => q.eq('userId', userId))
    .first();

  if (!stats) return;

  const achievementsToCheck = [
    // Word count achievements
    { type: 'word_count', key: 'words_100', progress: stats.totalWords },
    { type: 'word_count', key: 'words_1000', progress: stats.totalWords },
    { type: 'word_count', key: 'words_10000', progress: stats.totalWords },
    { type: 'word_count', key: 'words_50000', progress: stats.totalWords },
    { type: 'word_count', key: 'words_100000', progress: stats.totalWords },
    { type: 'word_count', key: 'words_500000', progress: stats.totalWords },
    { type: 'word_count', key: 'words_1000000', progress: stats.totalWords },

    // Language achievements
    { type: 'language', key: 'languages_2', progress: stats.languagesUsed.length },
    { type: 'language', key: 'languages_5', progress: stats.languagesUsed.length },
    { type: 'language', key: 'languages_10', progress: stats.languagesUsed.length },
    { type: 'language', key: 'languages_20', progress: stats.languagesUsed.length },

    // Streak achievements
    { type: 'streak', key: 'streak_7', progress: stats.longestStreak },
    { type: 'streak', key: 'streak_30', progress: stats.longestStreak },
    { type: 'streak', key: 'streak_100', progress: stats.longestStreak },
    { type: 'streak', key: 'streak_365', progress: stats.longestStreak },

    // Time achievements (convert minutes to hours)
    { type: 'time', key: 'time_1', progress: stats.totalMinutes / 60 },
    { type: 'time', key: 'time_10', progress: stats.totalMinutes / 60 },
    { type: 'time', key: 'time_50', progress: stats.totalMinutes / 60 },
    { type: 'time', key: 'time_100', progress: stats.totalMinutes / 60 },
    { type: 'time', key: 'time_500', progress: stats.totalMinutes / 60 },
  ];

  for (const achievement of achievementsToCheck) {
    const def = ACHIEVEMENT_DEFINITIONS[achievement.key as keyof typeof ACHIEVEMENT_DEFINITIONS];

    // Check if achievement already exists
    const existing = await ctx.db
      .query('achievements')
      .withIndex('by_userId_and_type', (q: any) =>
        q.eq('userId', userId).eq('achievementType', achievement.key)
      )
      .first();

    if (!existing) {
      // Create new achievement
      await ctx.db.insert('achievements', {
        userId,
        achievementType: achievement.key,
        progress: achievement.progress,
        target: def.target,
        unlockedAt: achievement.progress >= def.target ? Date.now() : undefined,
        tier: def.tier,
      });

      // If unlocked, create badge
      if (achievement.progress >= def.target) {
        await ctx.db.insert('badges', {
          userId,
          badgeId: achievement.key,
          badgeName: def.name,
          badgeDescription: def.description,
          badgeIcon: getBadgeIcon(achievement.type),
          unlockedAt: Date.now(),
          rarity: def.tier,
        });
      }
    } else if (!existing.unlockedAt && achievement.progress >= def.target) {
      // Update achievement to unlocked
      await ctx.db.patch(existing._id, {
        progress: achievement.progress,
        unlockedAt: Date.now(),
      });

      // Create badge
      await ctx.db.insert('badges', {
        userId,
        badgeId: achievement.key,
        badgeName: def.name,
        badgeDescription: def.description,
        badgeIcon: getBadgeIcon(achievement.type),
        unlockedAt: Date.now(),
        rarity: def.tier,
      });
    } else {
      // Just update progress
      await ctx.db.patch(existing._id, {
        progress: achievement.progress,
      });
    }
  }
}

function getBadgeIcon(type: string): string {
  const icons: Record<string, string> = {
    word_count: '📝',
    language: '🌍',
    streak: '🔥',
    time: '⏱️',
  };
  return icons[type] || '⭐';
}

// Get user achievements
export const getUserAchievements = query({
  args: { userId: v.id('users') },
  handler: async (ctx, args) => {
    const achievements = await ctx.db
      .query('achievements')
      .withIndex('by_userId', (q) => q.eq('userId', args.userId))
      .collect();

    return achievements.map((ach) => ({
      ...ach,
      definition: ACHIEVEMENT_DEFINITIONS[ach.achievementType as keyof typeof ACHIEVEMENT_DEFINITIONS],
    }));
  },
});

// Get user badges
export const getUserBadges = query({
  args: { userId: v.id('users') },
  handler: async (ctx, args) => {
    return await ctx.db
      .query('badges')
      .withIndex('by_userId', (q) => q.eq('userId', args.userId))
      .order('desc')
      .collect();
  },
});

// Get user stats
export const getUserStats = query({
  args: { userId: v.id('users') },
  handler: async (ctx, args) => {
    return await ctx.db
      .query('userStats')
      .withIndex('by_userId', (q) => q.eq('userId', args.userId))
      .first();
  },
});

// Update streak manually (called daily)
export const updateStreak = mutation({
  args: { userId: v.id('users') },
  handler: async (ctx, args) => {
    const stats = await ctx.db
      .query('userStats')
      .withIndex('by_userId', (q) => q.eq('userId', args.userId))
      .first();

    if (!stats) return;

    const today = new Date().toISOString().split('T')[0];
    const lastDate = new Date(stats.lastActiveDate);
    const todayDate = new Date(today);
    const daysDiff = Math.floor((todayDate.getTime() - lastDate.getTime()) / (1000 * 60 * 60 * 24));

    if (daysDiff > 1) {
      // Streak broken
      await ctx.db.patch(stats._id, {
        currentStreak: 0,
        updatedAt: Date.now(),
      });
    }
  },
});

// Get leaderboard
export const getLeaderboard = query({
  args: {
    metric: v.string(), // "words" | "streak" | "languages"
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const limit = args.limit || 10;
    const allStats = await ctx.db.query('userStats').collect();

    // Sort based on metric
    const sorted = allStats.sort((a, b) => {
      if (args.metric === 'words') return b.totalWords - a.totalWords;
      if (args.metric === 'streak') return b.longestStreak - a.longestStreak;
      if (args.metric === 'languages') return b.languagesUsed.length - a.languagesUsed.length;
      return 0;
    });

    return sorted.slice(0, limit);
  },
});
