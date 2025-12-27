'use client';

import { TrendingUp, Clock, Languages, ChevronRight, Settings, User } from '../components/icons';

export default function Dashboard() {
  return (
    <div className="min-h-screen bg-[#0a0a0f] text-white">
      {/* Background orbs */}
      <div className="fixed inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-0 -left-1/4 w-[600px] h-[600px] rounded-full bg-gradient-to-br from-purple-600/20 via-violet-600/10 to-transparent blur-3xl animate-glow"></div>
        <div className="absolute top-1/3 -right-1/4 w-[500px] h-[500px] rounded-full bg-gradient-to-bl from-blue-600/20 via-cyan-600/10 to-transparent blur-3xl animate-glow" style={{animationDelay: "1s"}}></div>
      </div>

      {/* Header */}
      <header className="relative backdrop-blur-xl bg-white/5 border-b border-white/10">
        <div className="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between">
          <div className="text-xl font-bold bg-gradient-to-r from-purple-400 via-pink-400 to-blue-400 bg-clip-text text-transparent">
            Talkies Dashboard
          </div>
          <div className="flex items-center gap-4">
            <button className="px-4 py-2 rounded-xl bg-white/5 border border-white/10 hover:bg-white/10 transition-all flex items-center gap-2">
              <Settings className="w-4 h-4" />
              Settings
            </button>
            <div className="w-10 h-10 rounded-full bg-gradient-to-br from-purple-600 to-pink-600 flex items-center justify-center">
              <User className="w-5 h-5 text-white" />
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="relative max-w-7xl mx-auto px-6 py-12">
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
              1,234
            </div>
            <div className="text-sm text-green-400">+23% this week</div>
          </div>

          <div className="group p-6 rounded-3xl backdrop-blur-xl bg-white/5 border border-white/10 hover:border-blue-500/50 transition-all">
            <div className="flex items-center gap-3 mb-3">
              <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-blue-500 to-cyan-500 flex items-center justify-center">
                <Clock className="w-5 h-5 text-white" />
              </div>
              <div className="text-sm text-neutral-400">Minutes Used</div>
            </div>
            <div className="text-4xl font-bold bg-gradient-to-r from-blue-400 to-cyan-400 bg-clip-text text-transparent mb-2">
              5,678
            </div>
            <div className="text-sm text-green-400">Unlimited</div>
          </div>

          <div className="group p-6 rounded-3xl backdrop-blur-xl bg-white/5 border border-white/10 hover:border-pink-500/50 transition-all">
            <div className="flex items-center gap-3 mb-3">
              <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-pink-500 to-orange-500 flex items-center justify-center">
                <Languages className="w-5 h-5 text-white" />
              </div>
              <div className="text-sm text-neutral-400">Languages Used</div>
            </div>
            <div className="text-4xl font-bold bg-gradient-to-r from-pink-400 to-orange-400 bg-clip-text text-transparent mb-2">
              12
            </div>
            <div className="text-sm text-neutral-400">100+ available</div>
          </div>
        </div>

        {/* Subscription Card */}
        <div className="mb-12 relative rounded-3xl overflow-hidden">
          <div className="absolute inset-0 bg-gradient-to-br from-purple-600 via-pink-600 to-blue-600 animate-gradient"></div>
          <div className="absolute inset-[2px] rounded-3xl bg-[#0a0a0f]"></div>
          <div className="relative p-8">
            <div className="flex items-center justify-between mb-6">
              <div>
                <h2 className="text-2xl font-bold mb-2">Talkies Pro</h2>
                <p className="text-neutral-400">Your subscription is active</p>
              </div>
              <div className="px-4 py-2 rounded-full bg-gradient-to-r from-green-500 to-emerald-500 text-white font-semibold">
                Active
              </div>
            </div>

            <div className="grid md:grid-cols-3 gap-6 mb-6">
              <div>
                <div className="text-sm text-neutral-400 mb-1">Plan</div>
                <div className="text-lg font-semibold">Pro Monthly</div>
              </div>
              <div>
                <div className="text-sm text-neutral-400 mb-1">Next Billing</div>
                <div className="text-lg font-semibold">Jan 15, 2025</div>
              </div>
              <div>
                <div className="text-sm text-neutral-400 mb-1">Amount</div>
                <div className="text-lg font-semibold">$10/month</div>
              </div>
            </div>

            <div className="flex gap-3">
              <button className="px-6 py-3 rounded-xl backdrop-blur-xl bg-white/10 border border-white/20 hover:bg-white/20 transition-all font-semibold">
                Update Payment
              </button>
              <button className="px-6 py-3 rounded-xl backdrop-blur-xl bg-white/10 border border-white/20 hover:bg-white/20 transition-all font-semibold">
                Change Plan
              </button>
              <button className="px-6 py-3 rounded-xl text-red-400 hover:text-red-300 transition-all font-semibold">
                Cancel Subscription
              </button>
            </div>
          </div>
        </div>

        {/* Recent Activity */}
        <div className="rounded-3xl backdrop-blur-xl bg-white/5 border border-white/10 p-8">
          <h2 className="text-2xl font-bold mb-6">Recent Transcriptions</h2>
          <div className="space-y-4">
            {[
              { title: 'Team Meeting Notes', time: '2 hours ago', duration: '45 min', language: 'English' },
              { title: 'Product Ideas', time: '5 hours ago', duration: '23 min', language: 'English' },
              { title: 'Interview Recording', time: '1 day ago', duration: '67 min', language: 'Spanish' },
              { title: 'Lecture Notes', time: '2 days ago', duration: '92 min', language: 'French' },
            ].map((item, i) => (
              <div
                key={i}
                className="p-4 rounded-2xl backdrop-blur-xl bg-white/5 border border-white/10 hover:border-purple-500/50 transition-all cursor-pointer group"
              >
                <div className="flex items-center justify-between">
                  <div className="flex-1">
                    <h3 className="font-semibold mb-1 group-hover:bg-gradient-to-r group-hover:from-purple-400 group-hover:to-pink-400 group-hover:bg-clip-text group-hover:text-transparent transition-all">
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
                  <ChevronRight className="w-5 h-5 text-neutral-400 group-hover:text-purple-400 transition-colors" />
                </div>
              </div>
            ))}
          </div>
        </div>
      </main>
    </div>
  );
}
