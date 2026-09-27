import type { Metadata } from "next";
import "./globals.css";
import { ToastProvider } from "./components/Toast/useToast";

const publicBasePath = process.env.NEXT_PUBLIC_BASE_PATH ?? "";
const publicAsset = (path: string) => `${publicBasePath}${path}`;
const siteUrl = process.env.NEXT_PUBLIC_SITE_URL ?? "https://talkies.app";

export const metadata: Metadata = {
  title: "Talkies — Open-source offline dictation",
  description: "An open-source, offline alternative to closed dictation apps. Local speech recognition and optional cleanup for macOS, Windows, and Linux, free under MIT.",
  keywords: ["voice to text", "transcription", "writing assistant", "productivity", "AI", "speech to text", "dictation"],
  authors: [{ name: "Talkies Team" }],
  creator: "Talkies",
  publisher: "Talkies",
  // Keep the base at the host root because metadata asset paths include /talkies.
  metadataBase: new URL(new URL(siteUrl).origin),

  // Open Graph
  openGraph: {
    type: "website",
    locale: "en_US",
    url: siteUrl,
    title: "Talkies — Open-source offline dictation",
    description: "An open-source, offline alternative to closed dictation apps. Local speech recognition and optional cleanup for macOS, Windows, and Linux.",
    siteName: "Talkies",
    images: [
      {
        url: publicAsset("/og-image.svg"),
        width: 1200,
        height: 630,
        alt: "Talkies — Open-source offline dictation",
        type: "image/svg+xml",
      },
    ],
  },

  // Twitter Card
  twitter: {
    card: "summary_large_image",
    title: "Talkies — Open-source offline dictation",
    description: "An open-source, offline alternative to closed dictation apps. Local speech recognition and optional cleanup for macOS, Windows, and Linux.",
    images: [publicAsset("/og-image.svg")],
    creator: "@talkiesapp", // Update with actual Twitter handle
    site: "@talkiesapp", // Update with actual Twitter handle
  },

  // Icons
  icons: {
    icon: [
      { url: publicAsset("/favicon.svg"), type: "image/svg+xml" },
      { url: publicAsset("/talkies-logo.svg"), type: "image/svg+xml", sizes: "any" },
    ],
    apple: [
      { url: publicAsset("/talkies-logo.svg"), type: "image/svg+xml" },
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
        className="antialiased"
      >
        <ToastProvider>{children}</ToastProvider>
      </body>
    </html>
  );
}
