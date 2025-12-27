'use client';

import { useState } from 'react';
import { Header } from '@/app/components/sections/Header';
import { Send, Mail, MessageSquare, Bug, Lightbulb, CreditCard, CheckCircle, Clock } from 'lucide-react';
import { useMutation } from 'convex/react';
import { api } from '@/convex/_generated/api';

export default function ContactPage() {
  const submitContactForm = useMutation(api.support.submitContactForm);

  const [formData, setFormData] = useState({
    email: '',
    category: 'general',
    subject: '',
    message: '',
  });

  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitSuccess, setSubmitSuccess] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setIsSubmitting(true);

    try {
      await submitContactForm({
        email: formData.email,
        category: formData.category,
        subject: formData.subject,
        message: formData.message,
      });

      setSubmitSuccess(true);
      setFormData({
        email: '',
        category: 'general',
        subject: '',
        message: '',
      });

      // Reset success message after 5 seconds
      setTimeout(() => setSubmitSuccess(false), 5000);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to submit form');
    } finally {
      setIsSubmitting(false);
    }
  };

  const categories = [
    { value: 'general', label: 'General Support', icon: MessageSquare },
    { value: 'bug', label: 'Bug Report', icon: Bug },
    { value: 'feature', label: 'Feature Request', icon: Lightbulb },
    { value: 'billing', label: 'Billing Issue', icon: CreditCard },
  ];

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
          <div className="text-center mb-12">
            <h1 className="text-5xl md:text-6xl font-bold mb-4">
              <span className="bg-gradient-to-r from-purple-300 to-pink-300 bg-clip-text text-transparent">
                Get in Touch
              </span>
            </h1>
            <p className="text-lg text-neutral-400 max-w-2xl mx-auto">
              Have a question? Found a bug? We're here to help.
            </p>
          </div>

          <div className="grid lg:grid-cols-3 gap-8">
            {/* Contact Form */}
            <div className="lg:col-span-2">
              <div className="rounded-2xl border border-white/10 bg-gradient-to-br from-white/10 to-white/5 p-8 backdrop-blur-xl">
                {submitSuccess ? (
                  <div className="text-center py-12">
                    <div className="inline-flex h-16 w-16 items-center justify-center rounded-full bg-green-500/20 mb-4">
                      <CheckCircle className="h-8 w-8 text-green-400" />
                    </div>
                    <h3 className="text-2xl font-bold mb-2">Message Sent!</h3>
                    <p className="text-neutral-400">
                      We'll get back to you within 24-48 hours.
                    </p>
                  </div>
                ) : (
                  <form onSubmit={handleSubmit} className="space-y-6">
                    {/* Email */}
                    <div>
                      <label htmlFor="email" className="block text-sm font-medium mb-2">
                        Email Address
                      </label>
                      <input
                        type="email"
                        id="email"
                        required
                        value={formData.email}
                        onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                        className="w-full rounded-lg border border-white/10 bg-white/5 px-4 py-3 text-white placeholder-neutral-500 focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-500/50"
                        placeholder="your@email.com"
                      />
                    </div>

                    {/* Category */}
                    <div>
                      <label htmlFor="category" className="block text-sm font-medium mb-2">
                        Category
                      </label>
                      <select
                        id="category"
                        value={formData.category}
                        onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                        className="w-full rounded-lg border border-white/10 bg-white/5 px-4 py-3 text-white focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-500/50"
                      >
                        {categories.map((cat) => (
                          <option key={cat.value} value={cat.value}>
                            {cat.label}
                          </option>
                        ))}
                      </select>
                    </div>

                    {/* Subject */}
                    <div>
                      <label htmlFor="subject" className="block text-sm font-medium mb-2">
                        Subject
                      </label>
                      <input
                        type="text"
                        id="subject"
                        required
                        minLength={3}
                        maxLength={200}
                        value={formData.subject}
                        onChange={(e) => setFormData({ ...formData, subject: e.target.value })}
                        className="w-full rounded-lg border border-white/10 bg-white/5 px-4 py-3 text-white placeholder-neutral-500 focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-500/50"
                        placeholder="Brief description of your issue"
                      />
                    </div>

                    {/* Message */}
                    <div>
                      <label htmlFor="message" className="block text-sm font-medium mb-2">
                        Message
                      </label>
                      <textarea
                        id="message"
                        required
                        minLength={10}
                        maxLength={5000}
                        rows={8}
                        value={formData.message}
                        onChange={(e) => setFormData({ ...formData, message: e.target.value })}
                        className="w-full rounded-lg border border-white/10 bg-white/5 px-4 py-3 text-white placeholder-neutral-500 focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-500/50 resize-none"
                        placeholder="Please provide as much detail as possible..."
                      />
                      <p className="text-xs text-neutral-500 mt-2">
                        {formData.message.length}/5000 characters
                      </p>
                    </div>

                    {/* Error Message */}
                    {error && (
                      <div className="rounded-lg bg-red-500/10 border border-red-500/20 p-4 text-red-300">
                        {error}
                      </div>
                    )}

                    {/* Submit Button */}
                    <button
                      type="submit"
                      disabled={isSubmitting}
                      className="w-full rounded-full bg-gradient-to-r from-purple-500 to-pink-500 px-8 py-4 font-semibold text-white transition-transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:scale-100"
                    >
                      {isSubmitting ? (
                        <span className="flex items-center justify-center gap-2">
                          <div className="h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent" />
                          Sending...
                        </span>
                      ) : (
                        <span className="flex items-center justify-center gap-2">
                          <Send className="h-5 w-5" />
                          Send Message
                        </span>
                      )}
                    </button>
                  </form>
                )}
              </div>
            </div>

            {/* Quick Links & Info */}
            <div className="space-y-6">
              {/* Quick Links */}
              <div className="rounded-2xl border border-white/10 bg-gradient-to-br from-white/10 to-white/5 p-6 backdrop-blur-xl">
                <h3 className="text-lg font-semibold mb-4">Quick Links</h3>
                <div className="space-y-3">
                  <a
                    href="https://docs.talkies.app"
                    className="flex items-center gap-3 rounded-lg bg-white/5 p-3 transition-colors hover:bg-white/10"
                  >
                    <span className="text-2xl">📚</span>
                    <div>
                      <p className="font-medium">Documentation</p>
                      <p className="text-xs text-neutral-400">Guides & tutorials</p>
                    </div>
                  </a>

                  <a
                    href="https://discord.gg/talkies"
                    className="flex items-center gap-3 rounded-lg bg-white/5 p-3 transition-colors hover:bg-white/10"
                  >
                    <span className="text-2xl">💬</span>
                    <div>
                      <p className="font-medium">Discord Community</p>
                      <p className="text-xs text-neutral-400">Chat with users</p>
                    </div>
                  </a>

                  <a
                    href="https://twitter.com/talkiesapp"
                    className="flex items-center gap-3 rounded-lg bg-white/5 p-3 transition-colors hover:bg-white/10"
                  >
                    <span className="text-2xl">🐦</span>
                    <div>
                      <p className="font-medium">Twitter / X</p>
                      <p className="text-xs text-neutral-400">Updates & announcements</p>
                    </div>
                  </a>

                  <a
                    href="mailto:support@talkies.app"
                    className="flex items-center gap-3 rounded-lg bg-white/5 p-3 transition-colors hover:bg-white/10"
                  >
                    <Mail className="h-6 w-6 text-purple-400" />
                    <div>
                      <p className="font-medium">Email Support</p>
                      <p className="text-xs text-neutral-400">support@talkies.app</p>
                    </div>
                  </a>
                </div>
              </div>

              {/* Response Times */}
              <div className="rounded-2xl border border-white/10 bg-gradient-to-br from-white/10 to-white/5 p-6 backdrop-blur-xl">
                <h3 className="text-lg font-semibold mb-4">Response Times</h3>
                <div className="space-y-3 text-sm">
                  <div className="flex items-start gap-2">
                    <Clock className="h-4 w-4 text-neutral-400 mt-0.5" />
                    <div>
                      <p className="text-white">General Support</p>
                      <p className="text-neutral-400">24-48 hours</p>
                    </div>
                  </div>

                  <div className="flex items-start gap-2">
                    <Clock className="h-4 w-4 text-neutral-400 mt-0.5" />
                    <div>
                      <p className="text-white">Bug Reports</p>
                      <p className="text-neutral-400">12-24 hours</p>
                    </div>
                  </div>

                  <div className="flex items-start gap-2">
                    <Clock className="h-4 w-4 text-neutral-400 mt-0.5" />
                    <div>
                      <p className="text-white">Billing Issues</p>
                      <p className="text-neutral-400">4-8 hours</p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
