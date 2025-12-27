import { TrendingUp, Users, Globe, Award } from 'lucide-react';

export function Stats() {
  return (
    <section className="relative py-20 px-6">
      <div className="max-w-6xl mx-auto relative z-10">
        <div className="grid md:grid-cols-4 gap-8">
          <div className="p-6 rounded-2xl backdrop-blur-xl bg-white/5 border border-white/10 text-center group hover:border-purple-500/50 transition-all">
            <div className="flex justify-center mb-3">
              <TrendingUp className="w-8 h-8 text-purple-400" />
            </div>
            <div className="text-5xl font-bold mb-2 bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text text-transparent">
              87%
            </div>
            <div className="text-neutral-400">Faster Writing</div>
          </div>
          <div className="p-6 rounded-2xl backdrop-blur-xl bg-white/5 border border-white/10 text-center group hover:border-blue-500/50 transition-all">
            <div className="flex justify-center mb-3">
              <Users className="w-8 h-8 text-blue-400" />
            </div>
            <div className="text-5xl font-bold mb-2 bg-gradient-to-r from-blue-400 to-cyan-400 bg-clip-text text-transparent">
              500K+
            </div>
            <div className="text-neutral-400">Active Users</div>
          </div>
          <div className="p-6 rounded-2xl backdrop-blur-xl bg-white/5 border border-white/10 text-center group hover:border-pink-500/50 transition-all">
            <div className="flex justify-center mb-3">
              <Globe className="w-8 h-8 text-pink-400" />
            </div>
            <div className="text-5xl font-bold mb-2 bg-gradient-to-r from-pink-400 to-orange-400 bg-clip-text text-transparent">
              100+
            </div>
            <div className="text-neutral-400">Languages</div>
          </div>
          <div className="p-6 rounded-2xl backdrop-blur-xl bg-white/5 border border-white/10 text-center group hover:border-green-500/50 transition-all">
            <div className="flex justify-center mb-3">
              <Award className="w-8 h-8 text-green-400" />
            </div>
            <div className="text-5xl font-bold mb-2 bg-gradient-to-r from-green-400 to-emerald-400 bg-clip-text text-transparent">
              4.9/5
            </div>
            <div className="text-neutral-400">User Rating</div>
          </div>
        </div>
      </div>
    </section>
  );
}
