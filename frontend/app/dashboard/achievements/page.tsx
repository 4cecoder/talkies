'use client';

import { useQuery } from 'convex/react';
import { api } from '@/convex/_generated/api';
import { Header } from '@/app/components/sections/Header';
import { Trophy, Lock, Award, TrendingUp } from 'lucide-react';
import { useState } from 'react';

// Mock user ID for now - replace with actual auth
const MOCK_USER_ID = 'mock_user_id' as any;

export default function AchievementsPage() {
  const achievements = useQuery(api.gamification.getUserAchievements, { userId: MOCK_USER_ID });
  const badges = useQuery(api.gamification.getUserBadges, { userId: MOCK_USER_ID });
  const stats = useQuery(api.gamification.getUserStats, { userId: MOCK_USER_ID });

  const [filter, setFilter] = useState<'all' | 'unlocked' | 'locked'>('all');

  if (!achievements || !badges || !stats) {
    return (
      <div className="min-h-screen bg-[#0a0a0f] text-white flex items-center justify-center">
        <div className="text-center">
          <div className="h-12 w-12 animate-spin rounded-full border-4 border-purple-500 border-t-transparent mx-auto mb-4" />
          <p className="text-neutral-400">Loading achievements...</p>
        </div>
      </div>
    );
  }

  const filteredAchievements = achievements.filter((ach) => {
    if (filter === 'unlocked') return !!ach.unlockedAt;
    if (filter === 'locked') return !ach.unlockedAt;
    return true;
  });

  const getTierColor = (tier: string) => {
    const colors: Record<string, string> = {
      bronze: 'from-orange-600 to-amber-600',
      silver: 'from-gray-400 to-gray-600',
      gold: 'from-yellow-400 to-yellow-600',
      platinum: 'from-purple-400 to-pink-500',
    };
    return colors[tier] || 'from-gray-400 to-gray-600';
  };

  const getTierBadgeColor = (tier: string) => {
    const colors: Record<string, string> = {
      bronze: 'bg-orange-500/20 text-orange-300 border-orange-500/30',
      silver: 'bg-gray-500/20 text-gray-300 border-gray-500/30',
      gold: 'bg-yellow-500/20 text-yellow-300 border-yellow-500/30',
      platinum: 'bg-purple-500/20 text-purple-300 border-purple-500/30',
    };
    return colors[tier] || 'bg-gray-500/20 text-gray-300 border-gray-500/30';
  };

  const unlockedCount = achievements.filter((a) => a.unlockedAt).length;
  const totalCount = achievements.length;
  const completionPercentage = Math.round((unlockedCount / totalCount) * 100);

  return (
    <div className="min-h-screen bg-[#0a0a0f] text-white">
      {/* Gradient background */}
      <div className="fixed inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-0 -left-1/4 w-[800px] h-[800px] rounded-full bg-gradient-to-br from-purple-600/20 via-violet-600/10 to-transparent blur-3xl"></div>
        <div className="absolute bottom-0 right-0 w-[600px] h-[600px] rounded-full bg-gradient-to-bl from-pink-600/15 via-fuchsia-600/10 to-transparent blur-3xl"></div>
      </div>

      <Header />

      <main className="relative pt-32 pb-20 px-6">
        <div className="max-w-6xl mx-auto">
          {/* Page Header */}
          <div className="mb-12">
            <h1 className="text-5xl md:text-6xl font-bold mb-4">
              <span className="bg-gradient-to-r from-purple-300 to-pink-300 bg-clip-text text-transparent">
                Achievements
              </span>
            </h1>
            <p className="text-lg text-neutral-400">
              Track your progress and unlock badges
            </p>
          </div>

          {/* Stats Overview */}
          <div className="grid md:grid-cols-4 gap-6 mb-8">
            <div className="rounded-2xl border border-white/10 bg-gradient-to-br from-white/10 to-white/5 p-6 backdrop-blur-xl">
              <div className="flex items-center gap-3 mb-2">
                <Trophy className="h-6 w-6 text-yellow-400" />
                <p className="text-sm text-neutral-400">Total</p>
              </div>
              <p className="text-3xl font-bold">{unlockedCount}/{totalCount}</p>
              <p className="text-xs text-neutral-500 mt-1">{completionPercentage}% Complete</p>
            </div>

            <div className="rounded-2xl border border-white/10 bg-gradient-to-br from-white/10 to-white/5 p-6 backdrop-blur-xl">
              <div className="flex items-center gap-3 mb-2">
                <Award className="h-6 w-6 text-purple-400" />
                <p className="text-sm text-neutral-400">Total Words</p>
              </div>
              <p className="text-3xl font-bold">{stats.totalWords.toLocaleString()}</p>
            </div>

            <div className="rounded-2xl border border-white/10 bg-gradient-to-br from-white/10 to-white/5 p-6 backdrop-blur-xl">
              <div className="flex items-center gap-3 mb-2">
                <TrendingUp className="h-6 w-6 text-green-400" />
                <p className="text-sm text-neutral-400">Current Streak</p>
              </div>
              <p className="text-3xl font-bold">{stats.currentStreak}</p>
              <p className="text-xs text-neutral-500 mt-1">days</p>
            </div>

            <div className="rounded-2xl border border-white/10 bg-gradient-to-br from-white/10 to-white/5 p-6 backdrop-blur-xl">
              <div className="flex items-center gap-3 mb-2">
                <span className="text-2xl">🌍</span>
                <p className="text-sm text-neutral-400">Languages</p>
              </div>
              <p className="text-3xl font-bold">{stats.languagesUsed.length}</p>
            </div>
          </div>

          {/* Filter Tabs */}
          <div className="flex gap-4 mb-8">
            <button
              onClick={() => setFilter('all')}
              className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                filter === 'all'
                  ? 'bg-gradient-to-r from-purple-500 to-pink-500 text-white'
                  : 'bg-white/5 text-neutral-400 hover:bg-white/10'
              }`}
            >
              All ({totalCount})
            </button>
            <button
              onClick={() => setFilter('unlocked')}
              className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                filter === 'unlocked'
                  ? 'bg-gradient-to-r from-purple-500 to-pink-500 text-white'
                  : 'bg-white/5 text-neutral-400 hover:bg-white/10'
              }`}
            >
              Unlocked ({unlockedCount})
            </button>
            <button
              onClick={() => setFilter('locked')}
              className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                filter === 'locked'
                  ? 'bg-gradient-to-r from-purple-500 to-pink-500 text-white'
                  : 'bg-white/5 text-neutral-400 hover:bg-white/10'
              }`}
            >
              Locked ({totalCount - unlockedCount})
            </button>
          </div>

          {/* Achievements Grid */}
          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
            {filteredAchievements.map((achievement) => {
              const isUnlocked = !!achievement.unlockedAt;
              const progress = Math.min((achievement.progress / achievement.target) * 100, 100);

              return (
                <div
                  key={achievement._id}
                  className={`relative rounded-2xl border p-6 backdrop-blur-xl transition-all hover:scale-105 ${
                    isUnlocked
                      ? 'border-white/20 bg-gradient-to-br from-white/10 to-white/5'
                      : 'border-white/10 bg-white/5 opacity-60'
                  }`}
                >
                  {/* Tier Badge */}
                  <div className="absolute top-4 right-4">
                    <span
                      className={`px-2 py-1 rounded-full text-xs font-semibold border ${getTierBadgeColor(
                        achievement.tier
                      )}`}
                    >
                      {achievement.tier.toUpperCase()}
                    </span>
                  </div>

                  {/* Icon */}
                  <div className="mb-4">
                    {isUnlocked ? (
                      <div
                        className={`inline-flex h-16 w-16 items-center justify-center rounded-2xl bg-gradient-to-br ${getTierColor(
                          achievement.tier
                        )} shadow-lg`}
                      >
                        <span className="text-3xl">
                          {achievement.achievementType.startsWith('words_') && '📝'}
                          {achievement.achievementType.startsWith('languages_') && '🌍'}
                          {achievement.achievementType.startsWith('streak_') && '🔥'}
                          {achievement.achievementType.startsWith('time_') && '⏱️'}
                        </span>
                      </div>
                    ) : (
                      <div className="inline-flex h-16 w-16 items-center justify-center rounded-2xl bg-white/5">
                        <Lock className="h-8 w-8 text-neutral-600" />
                      </div>
                    )}
                  </div>

                  {/* Title & Description */}
                  <h3 className="text-xl font-bold mb-2">
                    {achievement.definition?.name || 'Achievement'}
                  </h3>
                  <p className="text-sm text-neutral-400 mb-4">
                    {achievement.definition?.description || ''}
                  </p>

                  {/* Progress Bar */}
                  {!isUnlocked && (
                    <div className="mb-4">
                      <div className="flex justify-between text-xs text-neutral-500 mb-2">
                        <span>Progress</span>
                        <span>
                          {Math.floor(achievement.progress)}/{achievement.target}
                        </span>
                      </div>
                      <div className="h-2 w-full overflow-hidden rounded-full bg-white/10">
                        <div
                          className={`h-full bg-gradient-to-r ${getTierColor(achievement.tier)} transition-all duration-500`}
                          style={{ width: `${progress}%` }}
                        />
                      </div>
                    </div>
                  )}

                  {/* Unlock Date */}
                  {isUnlocked && achievement.unlockedAt && (
                    <p className="text-xs text-green-400">
                      Unlocked {new Date(achievement.unlockedAt).toLocaleDateString()}
                    </p>
                  )}
                </div>
              );
            })}
          </div>

          {/* Empty State */}
          {filteredAchievements.length === 0 && (
            <div className="text-center py-12">
              <Lock className="h-16 w-16 text-neutral-600 mx-auto mb-4" />
              <h3 className="text-xl font-semibold mb-2">No achievements found</h3>
              <p className="text-neutral-400">
                {filter === 'unlocked'
                  ? 'Start transcribing to unlock achievements!'
                  : 'All achievements unlocked!'}
              </p>
            </div>
          )}
        </div>
      </main>
    </div>
  );
}
