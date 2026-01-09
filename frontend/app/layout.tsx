import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import { ToastProvider } from "./components/Toast/useToast";
import { Providers } from "./components/providers";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
  display: 'swap',
  preload: true,
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
  display: 'swap',
  preload: true,
});

export const metadata: Metadata = {
  title: "Talkies - Voice-Powered Writing Assistant",
  description: "Write 3x faster with Talkies. Voice-powered writing assistant that helps you capture ideas instantly. Available now for macOS, with Windows and mobile coming soon.",
  keywords: ["voice to text", "transcription", "writing assistant", "productivity", "AI", "speech to text", "dictation"],
  authors: [{ name: "Talkies Team" }],
  creator: "Talkies",
  publisher: "Talkies",
  metadataBase: new URL('https://talkies.app'), // Update with actual domain

  // Open Graph
  openGraph: {
    type: "website",
    locale: "en_US",
    url: "https://talkies.app",
    title: "Talkies - Voice-Powered Writing Assistant",
    description: "Write 3x faster with Talkies. Voice-powered writing assistant that helps you capture ideas instantly. Available now for macOS.",
    siteName: "Talkies",
    images: [
      {
        url: "/og-image.svg",
        width: 1200,
        height: 630,
        alt: "Talkies - Voice-Powered Writing Assistant",
        type: "image/svg+xml",
      },
    ],
  },

  // Twitter Card
  twitter: {
    card: "summary_large_image",
    title: "Talkies - Voice-Powered Writing Assistant",
    description: "Write 3x faster with Talkies. Voice-powered writing assistant that helps you capture ideas instantly.",
    images: ["/og-image.svg"],
    creator: "@talkiesapp", // Update with actual Twitter handle
    site: "@talkiesapp", // Update with actual Twitter handle
  },

  // Icons
  icons: {
    icon: [
      { url: "/favicon.svg", type: "image/svg+xml" },
      { url: "/talkies-logo.svg", type: "image/svg+xml", sizes: "any" },
    ],
    apple: [
      { url: "/talkies-logo.svg", type: "image/svg+xml" },
    ],
  },

  // Additional metadata
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-video-preview': -1,
      'max-image-preview': 'large',
      'max-snippet': -1,
    },
  },

  // Verification (add actual tokens when available)
  // verification: {
  //   google: 'your-google-verification-token',
  //   yandex: 'your-yandex-verification-token',
  // },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased`}
      >
        <Providers>
          <ToastProvider>
            {children}
          </ToastProvider>
        </Providers>
      </body>
    </html>
  );
}
