import { Header } from '@/app/components/sections/Header';
import { LegalSection } from '@/app/components/legal/LegalSection';
import {
  Database,
  Clock,
  UserCheck,
  Cookie,
  Globe,
  Shield,
  Lock,
  XCircle,
  CheckCircle
} from 'lucide-react';

export const metadata = {
  title: 'Privacy Policy | Talkies',
  description: 'Privacy-first voice transcription. Your data stays on your device.',
};

export default function PrivacyPolicyPage() {
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
                Privacy Policy
              </span>
            </h1>
            <p className="text-lg text-neutral-400 max-w-2xl mx-auto">
              Your privacy isn't negotiable. Here's exactly what we collect (spoiler: almost nothing).
            </p>
            <p className="text-sm text-neutral-500 mt-4">
              Last updated: December 27, 2025
            </p>
          </div>

          {/* Data Flow Diagram */}
          <div className="mb-12 rounded-2xl border border-white/10 bg-gradient-to-br from-white/10 to-white/5 p-8 backdrop-blur-xl">
            <h2 className="text-2xl font-bold mb-6 text-white text-center">What We Collect (vs What We DON'T)</h2>

            <div className="grid md:grid-cols-2 gap-6">
              {/* NOT Collected */}
              <div className="space-y-4">
                <h3 className="text-lg font-semibold text-red-400 flex items-center gap-2">
                  <XCircle className="h-5 w-5" />
                  NOT Collected
                </h3>

                <div className="space-y-3">
                  <div className="flex items-start gap-3 p-3 rounded-lg bg-red-500/10 border border-red-500/20">
                    <span className="text-2xl">🎤</span>
                    <div>
                      <p className="font-medium text-white">Voice Recordings</p>
                      <p className="text-xs text-neutral-400">Processed locally on your device</p>
                    </div>
                  </div>

                  <div className="flex items-start gap-3 p-3 rounded-lg bg-red-500/10 border border-red-500/20">
                    <span className="text-2xl">📝</span>
                    <div>
                      <p className="font-medium text-white">Transcription Text</p>
                      <p className="text-xs text-neutral-400">Stays on your device, never uploaded</p>
                    </div>
                  </div>

                  <div className="flex items-start gap-3 p-3 rounded-lg bg-red-500/10 border border-red-500/20">
                    <span className="text-2xl">📍</span>
                    <div>
                      <p className="font-medium text-white">Location Data</p>
                      <p className="text-xs text-neutral-400">We don't track where you are</p>
                    </div>
                  </div>

                  <div className="flex items-start gap-3 p-3 rounded-lg bg-red-500/10 border border-red-500/20">
                    <span className="text-2xl">🔍</span>
                    <div>
                      <p className="font-medium text-white">Browsing History</p>
                      <p className="text-xs text-neutral-400">No tracking cookies or analytics</p>
                    </div>
                  </div>
                </div>
              </div>

              {/* Collected */}
              <div className="space-y-4">
                <h3 className="text-lg font-semibold text-green-400 flex items-center gap-2">
                  <CheckCircle className="h-5 w-5" />
                  What We Collect
                </h3>

                <div className="space-y-3">
                  <div className="flex items-start gap-3 p-3 rounded-lg bg-green-500/10 border border-green-500/20">
                    <span className="text-2xl">✉️</span>
                    <div>
                      <p className="font-medium text-white">Email Address</p>
                      <p className="text-xs text-neutral-400">For authentication only</p>
                    </div>
                  </div>

                  <div className="flex items-start gap-3 p-3 rounded-lg bg-green-500/10 border border-green-500/20">
                    <span className="text-2xl">💳</span>
                    <div>
                      <p className="font-medium text-white">Payment Info</p>
                      <p className="text-xs text-neutral-400">Via Stripe only (we never see it)</p>
                    </div>
                  </div>

                  <div className="flex items-start gap-3 p-3 rounded-lg bg-green-500/10 border border-green-500/20">
                    <span className="text-2xl">📊</span>
                    <div>
                      <p className="font-medium text-white">Usage Stats</p>
                      <p className="text-xs text-neutral-400">Word count, session duration (anonymized)</p>
                    </div>
                  </div>

                  <div className="flex items-start gap-3 p-3 rounded-lg bg-green-500/10 border border-green-500/20">
                    <span className="text-2xl">🖥️</span>
                    <div>
                      <p className="font-medium text-white">Device Type</p>
                      <p className="text-xs text-neutral-400">macOS/Windows for compatibility</p>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div className="mt-6 p-4 rounded-lg bg-purple-500/10 border border-purple-500/20 text-center">
              <p className="text-sm text-purple-300 font-medium">
                🔒 Your voice and transcriptions NEVER leave your device
              </p>
            </div>
          </div>

          {/* Detailed Sections */}
          <div className="space-y-4">
            <LegalSection
              icon={Database}
              title="1. Information We Collect"
              tldr="We collect minimal data: email for login, payment info via Stripe, and basic usage stats."
            >
              <p>
                <strong>Account Information:</strong>
              </p>
              <ul className="list-disc list-inside space-y-2 ml-4">
                <li>Email address (required for account creation and login)</li>
                <li>Name (optional, for personalization)</li>
                <li>Password (encrypted with bcrypt, we can't see it)</li>
              </ul>

              <p className="mt-4">
                <strong>Payment Information:</strong>
              </p>
              <ul className="list-disc list-inside space-y-2 ml-4">
                <li>Processed entirely through Stripe (PCI-DSS compliant)</li>
                <li>We only store your Stripe customer ID, not your card details</li>
                <li>We never have access to your full credit card number</li>
              </ul>

              <p className="mt-4">
                <strong>Usage Data (Anonymized):</strong>
              </p>
              <ul className="list-disc list-inside space-y-2 ml-4">
                <li>Total word count and transcription duration</li>
                <li>Languages used (for feature improvement)</li>
                <li>Device type (macOS/Windows for compatibility)</li>
                <li>App version (to track adoption of updates)</li>
              </ul>

              <p className="mt-4 p-3 rounded-lg bg-green-500/10 border border-green-500/20">
                <strong>What we DON'T collect:</strong> Voice recordings, transcription text, microphone access logs, or any content you create.
              </p>
            </LegalSection>

            <LegalSection
              icon={Shield}
              title="2. How We Use Your Data"
              tldr="We use your email to log you in and send important account updates. That's it."
            >
              <p>
                We use the information we collect for these purposes only:
              </p>
              <ul className="list-disc list-inside space-y-2 ml-4">
                <li><strong>Authentication:</strong> Email and password to securely log you in</li>
                <li><strong>Billing:</strong> Process payments and send receipts via Stripe</li>
                <li><strong>Customer Support:</strong> Respond to your questions and troubleshoot issues</li>
                <li><strong>Service Updates:</strong> Notify you about important changes, new features, or security alerts</li>
                <li><strong>Product Improvement:</strong> Anonymized usage stats to prioritize features</li>
              </ul>

              <p className="mt-4">
                <strong>We will NEVER:</strong>
              </p>
              <ul className="list-disc list-inside space-y-2 ml-4">
                <li>Sell your data to third parties</li>
                <li>Share your information with advertisers</li>
                <li>Send spam or marketing emails without your consent</li>
                <li>Access your voice recordings or transcriptions</li>
              </ul>
            </LegalSection>

            <LegalSection
              icon={Clock}
              title="3. Data Retention"
              tldr="We keep your account data as long as your account exists. Delete it anytime."
            >
              <p>
                <strong>Active Accounts:</strong> We retain your email and account preferences while your account is active.
              </p>
              <p>
                <strong>Deleted Accounts:</strong> When you delete your account, we immediately remove your email, name, and account data. Some anonymized usage stats may be retained for analytics.
              </p>
              <p>
                <strong>Payment Records:</strong> Stripe retains transaction records for 7 years (required by law for tax/fraud purposes).
              </p>
              <p>
                <strong>Local Data:</strong> Transcriptions stored on your device are under your control. Uninstalling the app deletes all local data.
              </p>
            </LegalSection>

            <LegalSection
              icon={UserCheck}
              title="4. Your Rights (GDPR & CCPA)"
              tldr="You have full control over your data. Download it, delete it, or opt-out anytime."
            >
              <p>
                Under GDPR (Europe) and CCPA (California), you have the right to:
              </p>
              <ul className="list-disc list-inside space-y-2 ml-4">
                <li><strong>Access:</strong> Request a copy of all data we have about you</li>
                <li><strong>Rectification:</strong> Update or correct inaccurate information</li>
                <li><strong>Deletion:</strong> Permanently delete your account and data</li>
                <li><strong>Portability:</strong> Export your data in a machine-readable format (JSON)</li>
                <li><strong>Opt-Out:</strong> Unsubscribe from non-essential emails</li>
              </ul>

              <p className="mt-4">
                To exercise these rights, go to your account settings or contact us at <a href="mailto:privacy@talkies.app" className="text-purple-400 hover:text-purple-300 underline">privacy@talkies.app</a>.
              </p>
            </LegalSection>

            <LegalSection
              icon={Cookie}
              title="5. Cookies & Tracking"
              tldr="We use essential cookies for login. No tracking or advertising cookies."
            >
              <p>
                <strong>Essential Cookies:</strong> We use session cookies to keep you logged in. These are required for the service to work.
              </p>
              <p>
                <strong>No Tracking Cookies:</strong> We do NOT use analytics cookies, advertising cookies, or third-party tracking pixels.
              </p>
              <p>
                <strong>Local Storage:</strong> The web app stores your preferences (theme, language) in your browser's local storage. This data never leaves your device.
              </p>
            </LegalSection>

            <LegalSection
              icon={Globe}
              title="6. Comparison to Cloud Competitors"
              tldr="Unlike cloud-based transcription services, we don't upload or analyze your voice data."
            >
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b border-white/10">
                      <th className="text-left py-2 px-3">Feature</th>
                      <th className="text-center py-2 px-3">Talkies</th>
                      <th className="text-center py-2 px-3">Cloud Services</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-white/5">
                    <tr>
                      <td className="py-2 px-3">Voice data uploaded</td>
                      <td className="text-center py-2 px-3">
                        <XCircle className="h-4 w-4 text-red-400 inline" />
                      </td>
                      <td className="text-center py-2 px-3">
                        <CheckCircle className="h-4 w-4 text-green-400 inline" />
                      </td>
                    </tr>
                    <tr>
                      <td className="py-2 px-3">Transcription stored on servers</td>
                      <td className="text-center py-2 px-3">
                        <XCircle className="h-4 w-4 text-red-400 inline" />
                      </td>
                      <td className="text-center py-2 px-3">
                        <CheckCircle className="h-4 w-4 text-green-400 inline" />
                      </td>
                    </tr>
                    <tr>
                      <td className="py-2 px-3">Data used for AI training</td>
                      <td className="text-center py-2 px-3">
                        <XCircle className="h-4 w-4 text-red-400 inline" />
                      </td>
                      <td className="text-center py-2 px-3">
                        <CheckCircle className="h-4 w-4 text-green-400 inline" />
                      </td>
                    </tr>
                    <tr>
                      <td className="py-2 px-3">Works offline</td>
                      <td className="text-center py-2 px-3">
                        <CheckCircle className="h-4 w-4 text-green-400 inline" />
                      </td>
                      <td className="text-center py-2 px-3">
                        <XCircle className="h-4 w-4 text-red-400 inline" />
                      </td>
                    </tr>
                    <tr>
                      <td className="py-2 px-3">Zero-knowledge architecture</td>
                      <td className="text-center py-2 px-3">
                        <CheckCircle className="h-4 w-4 text-green-400 inline" />
                      </td>
                      <td className="text-center py-2 px-3">
                        <XCircle className="h-4 w-4 text-red-400 inline" />
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </LegalSection>

            <LegalSection
              icon={Lock}
              title="7. Data Security"
              tldr="Industry-standard encryption, secure authentication, regular security audits."
            >
              <p>
                We take security seriously:
              </p>
              <ul className="list-disc list-inside space-y-2 ml-4">
                <li><strong>Encryption:</strong> All data transmitted over HTTPS (TLS 1.3)</li>
                <li><strong>Password Security:</strong> Bcrypt hashing with per-user salts</li>
                <li><strong>Database:</strong> Hosted on Convex with built-in encryption at rest</li>
                <li><strong>Payment Security:</strong> Stripe handles all payment processing (PCI-DSS Level 1 certified)</li>
                <li><strong>Infrastructure:</strong> Hosted on secure, SOC 2 compliant cloud providers</li>
              </ul>

              <p className="mt-4">
                Despite these measures, no method of transmission over the internet is 100% secure. We cannot guarantee absolute security.
              </p>
            </LegalSection>
          </div>

          {/* Contact Section */}
          <div className="mt-12 rounded-2xl border border-white/10 bg-gradient-to-br from-white/5 to-transparent p-8 text-center backdrop-blur-xl">
            <h3 className="text-xl font-semibold mb-2">Privacy Questions?</h3>
            <p className="text-neutral-400 mb-4">
              We're committed to transparency. Ask us anything.
            </p>
            <div className="flex flex-col sm:flex-row gap-4 justify-center">
              <a
                href="mailto:privacy@talkies.app"
                className="inline-flex items-center justify-center gap-2 rounded-full bg-gradient-to-r from-purple-500 to-pink-500 px-6 py-3 font-semibold text-white transition-transform hover:scale-105"
              >
                Email Privacy Team
              </a>
              <a
                href="/contact"
                className="inline-flex items-center justify-center gap-2 rounded-full border border-white/20 bg-white/5 px-6 py-3 font-semibold text-white transition-colors hover:bg-white/10"
              >
                Contact Form
              </a>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
