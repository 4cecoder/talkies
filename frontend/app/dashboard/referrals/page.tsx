'use client';

import { useQuery, useMutation } from 'convex/react';
import { api } from '@/convex/_generated/api';
import { Header } from '@/app/components/sections/Header';
import { Copy, Share2, Mail, CheckCircle, Trophy, Gift } from 'lucide-react';
import { useState } from 'react';

// Mock user ID for now - replace with actual auth
const MOCK_USER_ID = 'mock_user_id' as any;

export const dynamic = 'force-dynamic';

export default function ReferralsPage() {
  const stats = useQuery(api.referrals.getReferralStats, { userId: MOCK_USER_ID });
  const generateCode = useMutation(api.referrals.generateReferralCode);

  const [copied, setCopied] = useState(false);
  const [referralCode, setReferralCode] = useState<string | null>(null);

  // Generate referral code on mount
  useState(() => {
    generateCode({ userId: MOCK_USER_ID }).then((code) => setReferralCode(code));
  });

  const copyReferralLink = async () => {
    if (!referralCode) return;

    const link = `${window.location.origin}/?ref=${referralCode}`;
    await navigator.clipboard.writeText(link);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const shareViaEmail = () => {
    if (!referralCode) return;

    const subject = encodeURIComponent('Try Talkies - Voice Transcription App');
    const body = encodeURIComponent(
      `I've been using Talkies for voice transcription and it's amazing! Try it out with my referral link:\n\n${window.location.origin}/?ref=${referralCode}\n\nYou'll get a free trial, and I'll get a reward when you sign up!`
    );
    window.location.href = `mailto:?subject=${subject}&body=${body}`;
  };

  const shareViaTwitter = () => {
    if (!referralCode) return;

    const text = encodeURIComponent(
      `Just tried Talkies - the privacy-first voice transcription app that runs AI on YOUR device! 🎤\n\nTry it free:`
    );
    const url = encodeURIComponent(`${window.location.origin}/?ref=${referralCode}`);
    window.open(`https://twitter.com/intent/tweet?text=${text}&url=${url}`, '_blank');
  };

  if (!stats) {
    return (
      <div className="min-h-screen bg-[#0a0a0f] text-white flex items-center justify-center">
        <div className="text-center">
          <div className="h-12 w-12 animate-spin rounded-full border-4 border-purple-500 border-t-transparent mx-auto mb-4" />
          <p className="text-neutral-400">Loading referrals...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#0a0a0f] text-white">
      {/* Gradient background */}
      <div className="fixed inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-0 -left-1/4 w-[800px] h-[800px] rounded-full bg-gradient-to-br from-purple-600/20 via-violet-600/10 to-transparent blur-3xl"></div>
        <div className="absolute bottom-0 right-0 w-[600px] h-[600px] rounded-full bg-gradient-to-bl from-pink-600/15 via-fuchsia-600/10 to-transparent blur-3xl"></div>
      </div>

      <Header />

      <main className="relative pt-32 pb-20 px-6">
        <div className="max-w-4xl mx-auto">
          {/* Page Header */}
          <div className="text-center mb-12">
            <h1 className="text-5xl md:text-6xl font-bold mb-4">
              <span className="bg-gradient-to-r from-purple-300 to-pink-300 bg-clip-text text-transparent">
                Referral Program
              </span>
            </h1>
            <p className="text-lg text-neutral-400">
              Share Talkies with friends and earn rewards
            </p>
          </div>

          {/* Stats Grid */}
          <div className="grid md:grid-cols-3 gap-6 mb-8">
            <div className="rounded-2xl border border-white/10 bg-gradient-to-br from-white/10 to-white/5 p-6 backdrop-blur-xl text-center">
              <div className="inline-flex h-12 w-12 items-center justify-center rounded-full bg-gradient-to-r from-purple-500 to-pink-500 mb-3">
                <Share2 className="h-6 w-6 text-white" />
              </div>
              <p className="text-3xl font-bold mb-1">{stats.completed}</p>
              <p className="text-sm text-neutral-400">Successful Referrals</p>
            </div>

            <div className="rounded-2xl border border-white/10 bg-gradient-to-br from-white/10 to-white/5 p-6 backdrop-blur-xl text-center">
              <div className="inline-flex h-12 w-12 items-center justify-center rounded-full bg-gradient-to-r from-yellow-500 to-orange-500 mb-3">
                <Trophy className="h-6 w-6 text-white" />
              </div>
              <p className="text-3xl font-bold mb-1">{stats.unlockedRewards.length}</p>
              <p className="text-sm text-neutral-400">Rewards Unlocked</p>
            </div>

            <div className="rounded-2xl border border-white/10 bg-gradient-to-br from-white/10 to-white/5 p-6 backdrop-blur-xl text-center">
              <div className="inline-flex h-12 w-12 items-center justify-center rounded-full bg-gradient-to-r from-green-500 to-emerald-500 mb-3">
                <Gift className="h-6 w-6 text-white" />
              </div>
              <p className="text-3xl font-bold mb-1">{stats.pending}</p>
              <p className="text-sm text-neutral-400">Pending Referrals</p>
            </div>
          </div>

          {/* Referral Link Card */}
          <div className="rounded-2xl border border-white/10 bg-gradient-to-br from-white/10 to-white/5 p-8 backdrop-blur-xl mb-8">
            <h2 className="text-2xl font-bold mb-4">Your Referral Link</h2>
            <p className="text-neutral-400 mb-6">
              Share this link with friends to earn rewards
            </p>

            {referralCode ? (
              <>
                <div className="flex gap-3 mb-4">
                  <input
                    type="text"
                    readOnly
                    value={`${window.location.origin}/?ref=${referralCode}`}
                    className="flex-1 rounded-lg border border-white/10 bg-white/5 px-4 py-3 text-white"
                  />
                  <button
                    onClick={copyReferralLink}
                    className="flex items-center gap-2 rounded-lg bg-gradient-to-r from-purple-500 to-pink-500 px-6 py-3 font-semibold text-white transition-transform hover:scale-105"
                  >
                    {copied ? (
                      <>
                        <CheckCircle className="h-5 w-5" />
                        Copied!
                      </>
                    ) : (
                      <>
                        <Copy className="h-5 w-5" />
                        Copy
                      </>
                    )}
                  </button>
                </div>

                <div className="flex gap-3">
                  <button
                    onClick={shareViaEmail}
                    className="flex-1 flex items-center justify-center gap-2 rounded-lg border border-white/20 bg-white/5 px-4 py-3 font-semibold text-white transition-colors hover:bg-white/10"
                  >
                    <Mail className="h-5 w-5" />
                    Email
                  </button>
                  <button
                    onClick={shareViaTwitter}
                    className="flex-1 flex items-center justify-center gap-2 rounded-lg border border-white/20 bg-white/5 px-4 py-3 font-semibold text-white transition-colors hover:bg-white/10"
                  >
                    <Share2 className="h-5 w-5" />
                    Twitter
                  </button>
                </div>
              </>
            ) : (
              <div className="text-center py-4">
                <div className="h-8 w-8 animate-spin rounded-full border-4 border-purple-500 border-t-transparent mx-auto" />
              </div>
            )}
          </div>

          {/* Reward Tiers */}
          <div className="rounded-2xl border border-white/10 bg-gradient-to-br from-white/10 to-white/5 p-8 backdrop-blur-xl mb-8">
            <h2 className="text-2xl font-bold mb-6">Reward Tiers</h2>

            <div className="space-y-4">
              {[
                { count: 1, reward: '1 month free Pro' },
                { count: 5, reward: 'Lifetime 20% discount' },
                { count: 10, reward: 'Custom vocabulary unlock' },
                { count: 25, reward: 'Lifetime Pro access' },
              ].map((tier) => {
                const isUnlocked = stats.completed >= tier.count;
                const progress = Math.min((stats.completed / tier.count) * 100, 100);

                return (
                  <div
                    key={tier.count}
                    className={`rounded-lg border p-4 ${
                      isUnlocked
                        ? 'border-green-500/30 bg-green-500/10'
                        : 'border-white/10 bg-white/5'
                    }`}
                  >
                    <div className="flex items-center justify-between mb-2">
                      <div className="flex items-center gap-3">
                        {isUnlocked && <CheckCircle className="h-5 w-5 text-green-400" />}
                        <div>
                          <p className="font-semibold">{tier.reward}</p>
                          <p className="text-sm text-neutral-400">{tier.count} referrals</p>
                        </div>
                      </div>
                      <span
                        className={`text-sm font-semibold ${
                          isUnlocked ? 'text-green-400' : 'text-neutral-400'
                        }`}
                      >
                        {isUnlocked ? 'Unlocked!' : `${stats.completed}/${tier.count}`}
                      </span>
                    </div>

                    {!isUnlocked && (
                      <div className="h-2 w-full overflow-hidden rounded-full bg-white/10">
                        <div
                          className="h-full bg-gradient-to-r from-purple-500 to-pink-500 transition-all duration-500"
                          style={{ width: `${progress}%` }}
                        />
                      </div>
                    )}
                  </div>
                );
              })}
            </div>

            {stats.nextReward && (
              <div className="mt-6 p-4 rounded-lg bg-purple-500/10 border border-purple-500/20">
                <p className="text-sm text-purple-300">
                  <strong>Next reward:</strong> {stats.nextReward.reward} (
                  {stats.nextReward.count - stats.completed} more referrals needed)
                </p>
              </div>
            )}
          </div>

          {/* Recent Referrals */}
          <div className="rounded-2xl border border-white/10 bg-gradient-to-br from-white/10 to-white/5 p-8 backdrop-blur-xl">
            <h2 className="text-2xl font-bold mb-6">Recent Referrals</h2>

            {stats.referrals.length > 0 ? (
              <div className="space-y-3">
                {stats.referrals.slice(0, 10).map((referral) => (
                  <div
                    key={referral._id}
                    className="flex items-center justify-between rounded-lg border border-white/10 bg-white/5 p-4"
                  >
                    <div>
                      <p className="font-medium">{referral.refereeEmail || 'Pending...'}</p>
                      <p className="text-sm text-neutral-400">
                        {new Date(referral.createdAt).toLocaleDateString()}
                      </p>
                    </div>
                    <span
                      className={`rounded-full px-3 py-1 text-xs font-semibold ${
                        referral.status === 'completed'
                          ? 'bg-green-500/20 text-green-300'
                          : referral.status === 'rewarded'
                          ? 'bg-purple-500/20 text-purple-300'
                          : 'bg-yellow-500/20 text-yellow-300'
                      }`}
                    >
                      {referral.status}
                    </span>
                  </div>
                ))}
              </div>
            ) : (
              <div className="text-center py-8">
                <Share2 className="h-12 w-12 text-neutral-600 mx-auto mb-3" />
                <p className="text-neutral-400">No referrals yet</p>
                <p className="text-sm text-neutral-500">Start sharing your link to earn rewards!</p>
              </div>
            )}
          </div>
        </div>
      </main>
    </div>
  );
}
