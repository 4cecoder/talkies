'use client';

import { useSyncExternalStore } from 'react';
import type { PlatformId } from './site';

export type DetectedPlatform = PlatformId | 'unknown';

const subscribe = () => () => {};

function detect(): DetectedPlatform {
  const ua = navigator.userAgent.toLowerCase();
  if (ua.includes('android')) return 'android';
  if (/iphone|ipad|ipod/.test(ua)) return 'unknown';
  // iPadOS reports a Mac user agent; a touch screen gives it away.
  if (ua.includes('mac')) return navigator.maxTouchPoints > 1 ? 'unknown' : 'mac';
  if (ua.includes('win')) return 'windows';
  if (ua.includes('linux') || ua.includes('x11')) return 'linux';
  return 'unknown';
}

const serverSnapshot = (): DetectedPlatform => 'unknown';

/** The visitor's platform, or 'unknown' during prerender and for unsupported devices. */
export function usePlatform(): DetectedPlatform {
  return useSyncExternalStore(subscribe, detect, serverSnapshot);
}
