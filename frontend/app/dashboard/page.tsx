'use client';

import { useQuery } from 'convex/react';
import { api } from '@/convex/_generated/api';
import { TrendingUp, Clock, Languages, Settings, User, Download, Sparkles, Trophy } from '../components/icons';
import Link from 'next/link';

// Mock user ID for now - replace with actual auth
const MOCK_USER_ID = 'mock_user_id' as any;

export default function Dashboard() {
  const stats = useQuery(api.gamification.getUserStats, { userId: MOCK_USER_ID });
  const badges = useQuery(api.gamification.getUserBadges, { userId: MOCK_USER_ID });

  // Loading state
  if (stats === undefined) {
    return (
      <div className="min-h-screen bg-[#0a0a0f] text-white flex items-center justify-center">
        <div className="text-center">
          <div className="h-12 w-12 animate-spin rounded-full border-4 border-purple-500 border-t-transparent mx-auto mb-4" />
          <p className="text-neutral-400">Loading dashboard...</p>
        </div>
      </div>
    );
  }

  // Empty state for new users
  const isNewUser = !stats || stats.totalTranscriptions === 0;

  return (
    <div className="min-h-screen bg-[#0a0a0f] text-white">
      {/* Background orbs */}
      <div className="fixed inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-0 -left-1/4 w-[600px] h-[600px] rounded-full bg-gradient-to-br from-purple-600/20 via-violet-600/10 to-transparent blur-3xl animate-glow"></div>
        <div className="absolute top-1/3 -right-1/4 w-[500px] h-[500px] rounded-full bg-gradient-to-bl from-blue-600/20 via-cyan-600/10 to-transparent blur-3xl animate-glow" style={{animationDelay: "1s"}}></div>
      </div>

      {/* Header */}
      <header className="relative backdrop-blur-xl bg-white/5 border-b border-white/10">
        <div className="max-w-7xl mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            <div className="text-xl font-bold bg-gradient-to-r from-purple-400 via-pink-400 to-blue-400 bg-clip-text text-transparent">
              Talkies Dashboard
            </div>
            <div className="flex items-center gap-4">
              <Link
                href="/dashboard/achievements"
                className="px-4 py-2 rounded-xl bg-white/5 border border-white/10 hover:bg-white/10 transition-all flex items-center gap-2"
              >
                <Trophy className="w-4 h-4" />
                Achievements
              </Link>
              <Link
                href="/dashboard/referrals"
                className="px-4 py-2 rounded-xl bg-white/5 border border-white/10 hover:bg-white/10 transition-all flex items-center gap-2"
              >
                <Sparkles className="w-4 h-4" />
                Referrals
              </Link>
              <button className="px-4 py-2 rounded-xl bg-white/5 border border-white/10 hover:bg-white/10 transition-all flex items-center gap-2">
                <Settings className="w-4 h-4" />
                Settings
              </button>
              <div className="w-10 h-10 rounded-full bg-gradient-to-br from-purple-600 to-pink-600 flex items-center justify-center">
                <User className="w-5 h-5 text-white" />
              </div>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="relative max-w-7xl mx-auto px-6 py-12">
        {isNewUser ? (
          // Empty State for New Users
          <div className="text-center py-20">
            <div className="inline-flex h-24 w-24 items-center justify-center rounded-3xl bg-gradient-to-br from-purple-500 to-pink-500 mb-6">
              <Download className="h-12 w-12 text-white" />
            </div>
            <h2 className="text-4xl font-bold mb-4">
              <span className="bg-gradient-to-r from-purple-300 to-pink-300 bg-clip-text text-transparent">
                Ready to get started?
              </span>
            </h2>
            <p className="text-lg text-neutral-400 mb-8 max-w-2xl mx-auto">
              Download the Talkies desktop app to start transcribing with AI-powered voice recognition
            </p>

            <div className="flex flex-col sm:flex-row gap-4 justify-center mb-12">
              <Link
                href="/download"
                className="inline-flex items-center justify-center gap-2 rounded-full bg-gradient-to-r from-purple-500 to-pink-500 px-8 py-4 font-semibold text-white transition-transform hover:scale-105"
              >
                <Download className="h-5 w-5" />
                Download Desktop App
              </Link>
              <a
                href="/"
                className="inline-flex items-center justify-center gap-2 rounded-full border border-white/20 bg-white/5 px-8 py-4 font-semibold text-white transition-colors hover:bg-white/10"
              >
                Try Web Demo
              </a>
            </div>

            <div className="grid md:grid-cols-3 gap-6 max-w-4xl mx-auto">
              <div className="rounded-2xl border border-white/10 bg-white/5 p-6">
                <div className="text-4xl mb-3">🎤</div>
                <h3 className="font-semibold mb-2">1. Record</h3>
                <p className="text-sm text-neutral-400">
                  Click the mic button and start speaking
                </p>
              </div>
              <div className="rounded-2xl border border-white/10 bg-white/5 p-6">
                <div className="text-4xl mb-3">🤖</div>
                <h3 className="font-semibold mb-2">2. Transcribe</h3>
                <p className="text-sm text-neutral-400">
                  AI processes your voice instantly on your device
                </p>
              </div>
              <div className="rounded-2xl border border-white/10 bg-white/5 p-6">
                <div className="text-4xl mb-3">💾</div>
                <h3 className="font-semibold mb-2">3. Export</h3>
                <p className="text-sm text-neutral-400">
                  Save as text, SRT, or VTT format
                </p>
              </div>
            </div>
          </div>
        ) : (
          // Dashboard with Real Stats
          <>
            {/* Stats Grid */}
            <div className="grid md:grid-cols-3 gap-6 mb-12">
              <div className="group p-6 rounded-3xl backdrop-blur-xl bg-white/5 border border-white/10 hover:border-purple-500/50 transition-all">
                <div className="flex items-center gap-3 mb-3">
                  <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center">
                    <TrendingUp className="w-5 h-5 text-white" />
                  </div>
                  <div className="text-sm text-neutral-400">Total Transcriptions</div>
                </div>
                <div className="text-4xl font-bold bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text text-transparent mb-2">
                  {stats.totalTranscriptions.toLocaleString()}
                </div>
                <div className="text-sm text-neutral-400">
                  {stats.totalWords.toLocaleString()} words
                </div>
              </div>

              <div className="group p-6 rounded-3xl backdrop-blur-xl bg-white/5 border border-white/10 hover:border-blue-500/50 transition-all">
                <div className="flex items-center gap-3 mb-3">
                  <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-blue-500 to-cyan-500 flex items-center justify-center">
                    <Clock className="w-5 h-5 text-white" />
                  </div>
                  <div className="text-sm text-neutral-400">Minutes Used</div>
                </div>
                <div className="text-4xl font-bold bg-gradient-to-r from-blue-400 to-cyan-400 bg-clip-text text-transparent mb-2">
                  {Math.round(stats.totalMinutes).toLocaleString()}
                </div>
                <div className="text-sm text-neutral-400">
                  {(stats.totalMinutes / 60).toFixed(1)} hours
                </div>
              </div>

              <div className="group p-6 rounded-3xl backdrop-blur-xl bg-white/5 border border-white/10 hover:border-pink-500/50 transition-all">
                <div className="flex items-center gap-3 mb-3">
                  <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-pink-500 to-rose-500 flex items-center justify-center">
                    <Languages className="w-5 h-5 text-white" />
                  </div>
                  <div className="text-sm text-neutral-400">Languages Used</div>
                </div>
                <div className="text-4xl font-bold bg-gradient-to-r from-pink-400 to-rose-400 bg-clip-text text-transparent mb-2">
                  {stats.languagesUsed.length}
                </div>
                <div className="text-sm text-neutral-400">
                  {stats.currentStreak} day streak 🔥
                </div>
              </div>
            </div>

            {/* Recent Badges */}
            {badges && badges.length > 0 && (
              <div className="mb-12">
                <div className="flex items-center justify-between mb-6">
                  <h2 className="text-2xl font-bold">Recent Badges</h2>
                  <Link
                    href="/dashboard/achievements"
                    className="text-sm text-purple-400 hover:text-purple-300 transition-colors"
                  >
                    View All →
                  </Link>
                </div>
                <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                  {badges.slice(0, 4).map((badge) => (
                    <div
                      key={badge._id}
                      className="rounded-2xl border border-white/10 bg-white/5 p-6 text-center hover:border-purple-500/30 transition-all"
                    >
                      <div className="text-4xl mb-2">{badge.badgeIcon}</div>
                      <h3 className="font-semibold text-sm mb-1">{badge.badgeName}</h3>
                      <p className="text-xs text-neutral-400">{badge.badgeDescription}</p>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Quick Actions */}
            <div>
              <h2 className="text-2xl font-bold mb-6">Quick Actions</h2>
              <div className="grid md:grid-cols-2 gap-4">
                <Link
                  href="/download"
                  className="group p-6 rounded-2xl border border-white/10 bg-white/5 hover:border-purple-500/30 hover:bg-white/10 transition-all"
                >
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-4">
                      <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center">
                        <Download className="w-6 h-6 text-white" />
                      </div>
                      <div>
                        <h3 className="font-semibold">Download Desktop App</h3>
                        <p className="text-sm text-neutral-400">Get the full experience</p>
                      </div>
                    </div>
                    <span className="text-neutral-600 group-hover:text-neutral-400">→</span>
                  </div>
                </Link>

                <Link
                  href="/dashboard/referrals"
                  className="group p-6 rounded-2xl border border-white/10 bg-white/5 hover:border-purple-500/30 hover:bg-white/10 transition-all"
                >
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-4">
                      <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-yellow-500 to-orange-500 flex items-center justify-center">
                        <Sparkles className="w-6 h-6 text-white" />
                      </div>
                      <div>
                        <h3 className="font-semibold">Invite Friends</h3>
                        <p className="text-sm text-neutral-400">Earn rewards through referrals</p>
                      </div>
                    </div>
                    <span className="text-neutral-600 group-hover:text-neutral-400">→</span>
                  </div>
                </Link>
              </div>
            </div>
          </>
        )}
      </main>
    </div>
  );
}
