// Shared links and product facts for the marketing pages. Keep these in step
// with the README and platform guides on the application branch (master).

export const GITHUB_REPO_URL = 'https://github.com/4cecoder/talkies';
export const RELEASES_URL = `${GITHUB_REPO_URL}/releases/latest`;
export const ANDROID_APK_URL = `${GITHUB_REPO_URL}/releases/download/latest/Talkies-Android-latest.apk`;
export const ISSUES_URL = `${GITHUB_REPO_URL}/issues`;
export const NEW_ISSUE_URL = `${GITHUB_REPO_URL}/issues/new/choose`;
export const DISCUSSIONS_URL = `${GITHUB_REPO_URL}/discussions`;
export const docsUrl = (path: string) => `${GITHUB_REPO_URL}/blob/master/${path}`;
export const LICENSE_URL = docsUrl('LICENSE');
export const CONTRIBUTING_URL = docsUrl('CONTRIBUTING.md');
export const ROADMAP_URL = docsUrl('docs/ROADMAP.md');
export const FIRST_RUN_URL = docsUrl('docs/platforms/first-run-and-troubleshooting.md');

export type PlatformId = 'mac' | 'windows' | 'linux' | 'android';

export interface PlatformInfo {
  id: PlatformId;
  name: string;
  status: string;
  tone: 'ok' | 'warn';
  stack: string;
  requirements: string[];
  href: string;
  cta: string;
  guide: string;
}

export const platforms: PlatformInfo[] = [
  {
    id: 'mac',
    name: 'macOS',
    status: 'Available',
    tone: 'ok',
    stack: 'Swift and SwiftUI · WhisperKit',
    requirements: ['macOS 15 or later', 'Apple Silicon recommended', 'Microphone permission'],
    href: RELEASES_URL,
    cta: 'Download for macOS',
    guide: docsUrl('docs/platforms/macos.md'),
  },
  {
    id: 'windows',
    name: 'Windows',
    status: 'Available',
    tone: 'ok',
    stack: '.NET WPF · Whisper.net',
    requirements: ['Windows 10 or 11, 64-bit', 'Installer or portable ZIP', 'Optional CUDA or Vulkan runtime'],
    href: RELEASES_URL,
    cta: 'Download for Windows',
    guide: docsUrl('docs/platforms/windows.md'),
  },
  {
    id: 'linux',
    name: 'Linux',
    status: 'Available · maturing',
    tone: 'ok',
    stack: 'Zig · whisper.cpp · X11 and Wayland',
    requirements: ['x86_64 with AVX2', 'glibc 2.35 and GTK 4.6 or newer', 'GNOME, KDE, Hyprland, Sway, X11'],
    href: RELEASES_URL,
    cta: 'Download for Linux',
    guide: docsUrl('docs/platforms/linux.md'),
  },
  {
    id: 'android',
    name: 'Android',
    status: 'Early access · signed APK',
    tone: 'ok',
    stack: 'Kotlin and Compose · whisper.cpp',
    requirements: ['Android 9 (API 28) or newer', 'Includes Fire OS 7 and 8 tablets', 'Voice-typing keyboard'],
    href: ANDROID_APK_URL,
    cta: 'Download Android APK',
    guide: docsUrl('docs/platforms/mobile.md'),
  },
];
