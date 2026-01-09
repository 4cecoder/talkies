const faqs = [
  {
    question: "How does the voice transcription work?",
    answer: "Our app uses advanced speech recognition technology that runs directly on your device, ensuring privacy and offline functionality.",
    gradient: "from-green-300 to-emerald-300",
    hoverColor: "green-500"
  },
  {
    question: "Is my data secure?",
    answer: "Yes! Everything stays on your device. We never upload your voice recordings or transcriptions to the cloud.",
    gradient: "from-blue-300 to-cyan-300",
    hoverColor: "blue-500"
  },
  {
    question: "Can I use it offline?",
    answer: "Absolutely! The app works completely offline once installed. No internet connection required.",
    gradient: "from-purple-300 to-pink-300",
    hoverColor: "purple-500"
  }
];

export function FAQ() {
  return (
    <section id="faq" className="relative py-20 px-6">
      <div className="max-w-3xl mx-auto relative z-10">
        <h2 className="text-3xl md:text-4xl font-bold text-center mb-16">
          <span className="bg-gradient-to-r from-green-300 via-emerald-300 to-teal-300 bg-clip-text text-transparent">
            Frequently Asked Questions
          </span>
        </h2>

        <div className="space-y-6">
          {faqs.map((faq, index) => (
            <details key={index} className={`group p-6 rounded-2xl backdrop-blur-xl bg-white/5 border border-white/10 hover:border-${faq.hoverColor}/50 transition-all`}>
              <summary className={`font-semibold cursor-pointer text-lg bg-gradient-to-r ${faq.gradient} bg-clip-text text-transparent`}>
                {faq.question}
              </summary>
              <p className="mt-4 text-neutral-300 leading-relaxed">
                {faq.answer}
              </p>
            </details>
          ))}
        </div>
      </div>
    </section>
  );
}
