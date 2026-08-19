'use client';

import { Header } from '@/app/components/sections/Header';
import { LegalSection } from '@/app/components/legal/LegalSection';
import {
  FileText,
  UserPlus,
  Shield,
  AlertTriangle,
  Scale,
  Edit
} from 'lucide-react';
import { CheckCircle2, XCircle } from '@/app/components/icons';

export default function TermsOfServicePage() {
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
                Terms of Service
              </span>
            </h1>
            <p className="text-lg text-neutral-400 max-w-2xl mx-auto">
              Simple, transparent terms. No legalese tricks.
            </p>
            <p className="text-sm text-neutral-500 mt-4">
              Last updated: December 27, 2025
            </p>
          </div>

          {/* TL;DR Summary */}
          <div className="mb-12 rounded-2xl border border-white/10 bg-gradient-to-br from-white/10 to-white/5 p-8 backdrop-blur-xl">
            <h2 className="text-2xl font-bold mb-6 text-white">TL;DR - Quick Summary</h2>
            <div className="grid md:grid-cols-2 gap-4">
              <div className="flex items-start gap-3">
                <CheckCircle2 className="h-5 w-5 text-green-400 flex-shrink-0 mt-0.5" />
                <div>
                  <p className="text-white font-medium">You own your data</p>
                  <p className="text-sm text-neutral-400">All transcriptions belong to you</p>
                </div>
              </div>

              <div className="flex items-start gap-3">
                <CheckCircle2 className="h-5 w-5 text-green-400 flex-shrink-0 mt-0.5" />
                <div>
                  <p className="text-white font-medium">Free, forever</p>
                  <p className="text-sm text-neutral-400">No subscriptions, no hidden costs</p>
                </div>
              </div>

              <div className="flex items-start gap-3">
                <XCircle className="h-5 w-5 text-red-400 flex-shrink-0 mt-0.5" />
                <div>
                  <p className="text-white font-medium">No illegal use</p>
                  <p className="text-sm text-neutral-400">Don't transcribe copyrighted material</p>
                </div>
              </div>

              <div className="flex items-start gap-3">
                <XCircle className="h-5 w-5 text-red-400 flex-shrink-0 mt-0.5" />
                <div>
                  <p className="text-white font-medium">No harmful content</p>
                  <p className="text-sm text-neutral-400">Respect others, no hate speech</p>
                </div>
              </div>
            </div>
          </div>

          {/* Detailed Sections */}
          <div className="space-y-4">
            <LegalSection
              icon={FileText}
              title="1. Acceptance of Terms"
              tldr="By using Talkies, you agree to these terms. If you don't agree, please don't use our service."
            >
              <p>
                By accessing or using Talkies, you acknowledge that you have read, understood, and agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use our service.
              </p>
              <p>
                We may update these terms from time to time. Continued use of Talkies after changes constitutes acceptance of the new terms.
              </p>
            </LegalSection>

            <LegalSection
              icon={UserPlus}
              title="2. User Registration"
              tldr="Create an account with a valid email. Keep your password secure. You're responsible for your account activity."
            >
              <p>
                To access certain features, you must create an account with a valid email address and password. You are responsible for:
              </p>
              <ul className="list-disc list-inside space-y-2 ml-4">
                <li>Maintaining the confidentiality of your account credentials</li>
                <li>All activities that occur under your account</li>
                <li>Notifying us immediately of any unauthorized access</li>
              </ul>
              <p>
                You must be at least 13 years old to use Talkies. If you're under 18, you must have parental consent.
              </p>
            </LegalSection>

            <LegalSection
              icon={Shield}
              title="4. Privacy & Data"
              tldr="Voice recordings stay on YOUR device. We only collect email for login. See our Privacy Policy for details."
            >
              <p>
                <strong>Your Privacy is Our Priority:</strong>
              </p>
              <ul className="list-disc list-inside space-y-2 ml-4">
                <li>Voice recordings are processed entirely on your device (desktop apps)</li>
                <li>We do NOT collect, store, or transmit your voice data to our servers</li>
                <li>Transcription text is stored locally on your device only</li>
                <li>We only collect your email address for authentication purposes</li>
              </ul>
              <p>
                For complete details, please read our <a href="/legal/privacy" className="text-purple-400 hover:text-purple-300 underline">Privacy Policy</a>.
              </p>
            </LegalSection>

            <LegalSection
              icon={AlertTriangle}
              title="5. Acceptable Use Policy"
              tldr="Use Talkies responsibly. No illegal content, no abuse, no copyright infringement."
            >
              <p>
                You agree NOT to use Talkies for:
              </p>
              <ul className="list-disc list-inside space-y-2 ml-4">
                <li>Illegal activities or content that violates any laws</li>
                <li>Transcribing copyrighted material without permission</li>
                <li>Creating, distributing, or promoting harmful, abusive, or hate speech content</li>
                <li>Attempting to reverse engineer, hack, or compromise our services</li>
                <li>Reselling or redistributing our service without authorization</li>
                <li>Automated or bulk transcription for commercial purposes without a business license</li>
              </ul>
              <p>
                Violation of these terms may result in immediate account suspension or termination.
              </p>
            </LegalSection>

            <LegalSection
              icon={Scale}
              title="6. Limitation of Liability"
              tldr="We provide the service 'as is'. We're not liable for data loss or service interruptions. Use at your own risk."
            >
              <p>
                Talkies is provided "as is" without warranties of any kind, either express or implied. We do our best to provide reliable service, but we cannot guarantee:
              </p>
              <ul className="list-disc list-inside space-y-2 ml-4">
                <li>Uninterrupted or error-free operation</li>
                <li>100% accuracy in transcriptions</li>
                <li>Compatibility with all devices or browsers</li>
                <li>That the service will meet your specific requirements</li>
              </ul>
              <p>
                To the maximum extent permitted by law, we are not liable for any indirect, incidental, or consequential damages arising from your use of Talkies.
              </p>
              <p>
                <strong>Data Backup:</strong> You are solely responsible for backing up your transcriptions. We recommend exporting important content regularly.
              </p>
            </LegalSection>

            <LegalSection
              icon={Edit}
              title="7. Changes to Terms"
              tldr="We may update these terms. We'll notify you by email 30 days before major changes take effect."
            >
              <p>
                We reserve the right to modify these Terms of Service at any time. When we make changes:
              </p>
              <ul className="list-disc list-inside space-y-2 ml-4">
                <li>Minor updates: Posted on this page with an updated "Last Updated" date</li>
                <li>Major changes: You'll receive an email notification 30 days in advance</li>
                <li>Continued use after changes constitutes acceptance of the new terms</li>
              </ul>
              <p>
                If you don't agree with the updated terms, you can cancel your account before they take effect.
              </p>
            </LegalSection>
          </div>

          {/* Contact Section */}
          <div className="mt-12 rounded-2xl border border-white/10 bg-gradient-to-br from-white/5 to-transparent p-8 text-center backdrop-blur-xl">
            <h3 className="text-xl font-semibold mb-2">Questions about these terms?</h3>
            <p className="text-neutral-400 mb-4">
              We're here to help. Reach out anytime.
            </p>
            <a
              href="/contact"
              className="inline-flex items-center justify-center gap-2 rounded-full bg-gradient-to-r from-purple-500 to-pink-500 px-6 py-3 font-semibold text-white transition-transform hover:scale-105"
            >
              Contact Support
            </a>
          </div>
        </div>
      </main>
    </div>
  );
}
