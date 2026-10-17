import type { Metadata, Viewport } from "next";
import "./globals.css";
import { ToastProvider } from "./components/Toast/useToast";

const publicBasePath = process.env.NEXT_PUBLIC_BASE_PATH ?? "";
const publicAsset = (path: string) => `${publicBasePath}${path}`;
const siteUrl = process.env.NEXT_PUBLIC_SITE_URL ?? "https://talkies.app";

export const metadata: Metadata = {
  title: "Talkies — Open-source offline dictation",
  description: "Open-source, on-device dictation for macOS, Windows, Linux, and Android. Local speech recognition and optional cleanup, free under MIT. No account, no cloud.",
  keywords: ["dictation", "speech to text", "voice typing", "offline", "on-device", "open source", "Whisper", "privacy"],
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
    description: "Open-source, on-device dictation for macOS, Windows, Linux, and Android. Speech recognition and cleanup run locally after a one-time model download.",
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
    description: "Open-source, on-device dictation for macOS, Windows, Linux, and Android. Speech recognition and cleanup run locally after a one-time model download.",
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

export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: dark)", color: "#07070b" },
    { media: "(prefers-color-scheme: light)", color: "#fbfbfd" },
  ],
  colorScheme: "dark light",
};

// Runs before first paint: applies a saved theme choice and marks JS as
// available so scroll-reveal styles never hide content for no-JS visitors.
const themeBootstrap = `try{var d=document.documentElement;d.classList.add('js');var t=localStorage.getItem('talkies-theme');if(t==='light'||t==='dark')d.dataset.theme=t}catch(e){}`;

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeBootstrap }} />
      </head>
      <body className="bg-bg text-fg antialiased">
        <ToastProvider>{children}</ToastProvider>
      </body>
    </html>
  );
}
