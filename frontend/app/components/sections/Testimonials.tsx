import { Star } from '../icons';

const testimonials = [
  {
    quote: "Talkies has completely transformed my workflow. I can now write articles 3x faster just by speaking my thoughts. Game changer!",
    author: "Sarah Miller",
    role: "Tech Journalist",
    initials: "SM",
    gradient: "from-purple-600 to-pink-600"
  },
  {
    quote: "The accuracy is incredible. Works perfectly offline and my data stays private. Exactly what I needed for client meetings.",
    author: "James Davis",
    role: "Product Manager",
    initials: "JD",
    gradient: "from-blue-600 to-cyan-600"
  },
  {
    quote: "As a non-native English speaker, Talkies helps me write professional emails effortlessly. The multi-language support is fantastic!",
    author: "Maria Lopez",
    role: "Content Creator",
    initials: "ML",
    gradient: "from-pink-600 to-orange-600"
  }
];

export function Testimonials() {
  return (
    <section id="testimonials" className="relative py-20 px-6">
      <div className="max-w-6xl mx-auto relative z-10">
        <h2 className="text-3xl md:text-4xl font-bold text-center mb-4">
          <span className="bg-gradient-to-r from-yellow-300 via-orange-300 to-pink-300 bg-clip-text text-transparent">
            Loved by Creators Worldwide
          </span>
        </h2>
        <p className="text-center text-neutral-400 mb-16 max-w-2xl mx-auto">
          Join thousands of writers, journalists, and content creators who use Talkies daily
        </p>

        <div className="grid md:grid-cols-3 gap-8">
          {testimonials.map((testimonial, index) => (
            <div key={index} className="group relative p-8 rounded-3xl backdrop-blur-xl bg-white/5 border border-white/10 hover:border-purple-500/50 transition-all">
              <div className={`absolute inset-0 rounded-3xl bg-gradient-to-br ${index === 0 ? 'from-purple-600' : index === 1 ? 'from-blue-600' : 'from-pink-600'}/10 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity`}></div>
              <div className="relative">
                <div className="flex gap-1 mb-4">
                  {[...Array(5)].map((_, i) => (
                    <Star key={i} className="w-5 h-5 text-yellow-400 fill-yellow-400" />
                  ))}
                </div>
                <p className="text-neutral-300 mb-6 leading-relaxed">
                  &quot;{testimonial.quote}&quot;
                </p>
                <div className="flex items-center gap-3">
                  <div className={`w-12 h-12 rounded-full bg-gradient-to-br ${testimonial.gradient} flex items-center justify-center font-bold`}>
                    {testimonial.initials}
                  </div>
                  <div>
                    <div className="font-semibold">{testimonial.author}</div>
                    <div className="text-sm text-neutral-400">{testimonial.role}</div>
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
