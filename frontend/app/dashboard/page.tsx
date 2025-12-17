"use client";

import {
  TrendingUp,
  Clock,
  Languages,
  ChevronRight,
  Settings,
  User,
} from "lucide-react";

export default function Dashboard() {
  return (
    <div className="min-h-screen bg-[#0a0a0f] text-white">
      {/* Background orbs */}
      <div className="pointer-events-none fixed inset-0 overflow-hidden">
        <div className="animate-glow absolute top-0 -left-1/4 h-[600px] w-[600px] rounded-full bg-gradient-to-br from-purple-600/20 via-violet-600/10 to-transparent blur-3xl"></div>
        <div
          className="animate-glow absolute top-1/3 -right-1/4 h-[500px] w-[500px] rounded-full bg-gradient-to-bl from-blue-600/20 via-cyan-600/10 to-transparent blur-3xl"
          style={{ animationDelay: "1s" }}
        ></div>
      </div>

      {/* Header */}
      <header className="relative border-b border-white/10 bg-white/5 backdrop-blur-xl">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-6 py-4">
          <div className="bg-gradient-to-r from-purple-400 via-pink-400 to-blue-400 bg-clip-text text-xl font-bold text-transparent">
            Talkies Dashboard
          </div>
          <div className="flex items-center gap-4">
            <button className="flex items-center gap-2 rounded-xl border border-white/10 bg-white/5 px-4 py-2 transition-all hover:bg-white/10">
              <Settings className="h-4 w-4" />
              Settings
            </button>
            <div className="flex h-10 w-10 items-center justify-center rounded-full bg-gradient-to-br from-purple-600 to-pink-600">
              <User className="h-5 w-5 text-white" />
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="relative mx-auto max-w-7xl px-6 py-12">
        {/* Stats Grid */}
        <div className="mb-12 grid gap-6 md:grid-cols-3">
          <div className="group rounded-3xl border border-white/10 bg-white/5 p-6 backdrop-blur-xl transition-all hover:border-purple-500/50">
            <div className="mb-3 flex items-center gap-3">
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-br from-purple-500 to-pink-500">
                <TrendingUp className="h-5 w-5 text-white" />
              </div>
              <div className="text-sm text-neutral-400">
                Total Transcriptions
              </div>
            </div>
            <div className="mb-2 bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text text-4xl font-bold text-transparent">
              1,234
            </div>
            <div className="text-sm text-green-400">+23% this week</div>
          </div>

          <div className="group rounded-3xl border border-white/10 bg-white/5 p-6 backdrop-blur-xl transition-all hover:border-blue-500/50">
            <div className="mb-3 flex items-center gap-3">
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-br from-blue-500 to-cyan-500">
                <Clock className="h-5 w-5 text-white" />
              </div>
              <div className="text-sm text-neutral-400">Minutes Used</div>
            </div>
            <div className="mb-2 bg-gradient-to-r from-blue-400 to-cyan-400 bg-clip-text text-4xl font-bold text-transparent">
              5,678
            </div>
            <div className="text-sm text-green-400">Unlimited</div>
          </div>

          <div className="group rounded-3xl border border-white/10 bg-white/5 p-6 backdrop-blur-xl transition-all hover:border-pink-500/50">
            <div className="mb-3 flex items-center gap-3">
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-br from-pink-500 to-orange-500">
                <Languages className="h-5 w-5 text-white" />
              </div>
              <div className="text-sm text-neutral-400">Languages Used</div>
            </div>
            <div className="mb-2 bg-gradient-to-r from-pink-400 to-orange-400 bg-clip-text text-4xl font-bold text-transparent">
              12
            </div>
            <div className="text-sm text-neutral-400">100+ available</div>
          </div>
        </div>

        {/* Subscription Card */}
        <div className="relative mb-12 overflow-hidden rounded-3xl">
          <div className="animate-gradient absolute inset-0 bg-gradient-to-br from-purple-600 via-pink-600 to-blue-600"></div>
          <div className="absolute inset-[2px] rounded-3xl bg-[#0a0a0f]"></div>
          <div className="relative p-8">
            <div className="mb-6 flex items-center justify-between">
              <div>
                <h2 className="mb-2 text-2xl font-bold">Talkies Pro</h2>
                <p className="text-neutral-400">Your subscription is active</p>
              </div>
              <div className="rounded-full bg-gradient-to-r from-green-500 to-emerald-500 px-4 py-2 font-semibold text-white">
                Active
              </div>
            </div>

            <div className="mb-6 grid gap-6 md:grid-cols-3">
              <div>
                <div className="mb-1 text-sm text-neutral-400">Plan</div>
                <div className="text-lg font-semibold">Pro Monthly</div>
              </div>
              <div>
                <div className="mb-1 text-sm text-neutral-400">
                  Next Billing
                </div>
                <div className="text-lg font-semibold">Jan 15, 2025</div>
              </div>
              <div>
                <div className="mb-1 text-sm text-neutral-400">Amount</div>
                <div className="text-lg font-semibold">$10/month</div>
              </div>
            </div>

            <div className="flex gap-3">
              <button className="rounded-xl border border-white/20 bg-white/10 px-6 py-3 font-semibold backdrop-blur-xl transition-all hover:bg-white/20">
                Update Payment
              </button>
              <button className="rounded-xl border border-white/20 bg-white/10 px-6 py-3 font-semibold backdrop-blur-xl transition-all hover:bg-white/20">
                Change Plan
              </button>
              <button className="rounded-xl px-6 py-3 font-semibold text-red-400 transition-all hover:text-red-300">
                Cancel Subscription
              </button>
            </div>
          </div>
        </div>

        {/* Recent Activity */}
        <div className="rounded-3xl border border-white/10 bg-white/5 p-8 backdrop-blur-xl">
          <h2 className="mb-6 text-2xl font-bold">Recent Transcriptions</h2>
          <div className="space-y-4">
            {[
              {
                title: "Team Meeting Notes",
                time: "2 hours ago",
                duration: "45 min",
                language: "English",
              },
              {
                title: "Product Ideas",
                time: "5 hours ago",
                duration: "23 min",
                language: "English",
              },
              {
                title: "Interview Recording",
                time: "1 day ago",
                duration: "67 min",
                language: "Spanish",
              },
              {
                title: "Lecture Notes",
                time: "2 days ago",
                duration: "92 min",
                language: "French",
              },
            ].map((item, i) => (
              <div
                key={i}
                className="group cursor-pointer rounded-2xl border border-white/10 bg-white/5 p-4 backdrop-blur-xl transition-all hover:border-purple-500/50"
              >
                <div className="flex items-center justify-between">
                  <div className="flex-1">
                    <h3 className="mb-1 font-semibold transition-all group-hover:bg-gradient-to-r group-hover:from-purple-400 group-hover:to-pink-400 group-hover:bg-clip-text group-hover:text-transparent">
                      {item.title}
                    </h3>
                    <div className="flex items-center gap-4 text-sm text-neutral-400">
                      <span>{item.time}</span>
                      <span>•</span>
                      <span>{item.duration}</span>
                      <span>•</span>
                      <span>{item.language}</span>
                    </div>
                  </div>
                  <ChevronRight className="h-5 w-5 text-neutral-400 transition-colors group-hover:text-purple-400" />
                </div>
              </div>
            ))}
          </div>
        </div>
      </main>
    </div>
  );
}
