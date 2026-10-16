'use client';

import { useEffect, useRef, useState } from 'react';

type WaveState = 'pending' | 'ready' | 'fallback';

/**
 * Decorative WebGL2 waveform. The CSS gradient underneath is the first paint
 * and the fallback; the canvas fades in once a frame has rendered. The
 * renderer is loaded and started only when the browser is idle after load.
 */
export function HeroWave() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [state, setState] = useState<WaveState>('pending');

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    let disposed = false;
    let stop: (() => void) | undefined;
    let idleHandle: number | undefined;
    let timeoutHandle: ReturnType<typeof setTimeout> | undefined;

    const start = () => {
      import('@/app/lib/hero-wave')
        .then(({ startHeroWave }) => {
          if (disposed) return;
          stop = startHeroWave(canvas, {
            onReady: () => !disposed && setState('ready'),
            onFail: () => !disposed && setState('fallback'),
          });
        })
        .catch(() => !disposed && setState('fallback'));
    };

    const scheduleStart = () => {
      if ('requestIdleCallback' in window) {
        idleHandle = window.requestIdleCallback(start, { timeout: 2000 });
      } else {
        timeoutHandle = setTimeout(start, 250);
      }
    };

    if (document.readyState === 'complete') {
      scheduleStart();
    } else {
      window.addEventListener('load', scheduleStart, { once: true });
    }

    return () => {
      disposed = true;
      window.removeEventListener('load', scheduleStart);
      if (idleHandle !== undefined) window.cancelIdleCallback(idleHandle);
      if (timeoutHandle !== undefined) clearTimeout(timeoutHandle);
      stop?.();
    };
  }, []);

  return (
    <div className="pointer-events-none absolute inset-0" aria-hidden="true" data-hero-wave={state}>
      <div className="hero-fallback absolute inset-0" />
      <canvas
        ref={canvasRef}
        className={`hero-band-mask absolute inset-0 h-full w-full transition-opacity duration-[1400ms] ease-out ${
          state === 'ready' ? 'opacity-100' : 'opacity-0'
        }`}
      />
    </div>
  );
}
