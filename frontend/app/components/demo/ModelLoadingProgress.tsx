'use client';

import { Loader2 } from 'lucide-react';

interface ModelLoadingProgressProps {
  progress: number;
}

export function ModelLoadingProgress({ progress }: ModelLoadingProgressProps) {
  return (
    <div className="flex flex-col items-center justify-center space-y-4">
      <div className="relative">
        <Loader2 className="h-12 w-12 animate-spin text-purple-400" />
        <div className="absolute inset-0 flex items-center justify-center">
          <span className="text-xs font-bold text-white">{progress}%</span>
        </div>
      </div>

      <div className="w-full max-w-md space-y-2">
        <div className="h-2 w-full overflow-hidden rounded-full bg-white/10">
          <div
            className="h-full bg-gradient-to-r from-purple-500 to-pink-500 transition-all duration-300 ease-out"
            style={{ width: `${progress}%` }}
          />
        </div>

        <p className="text-center text-sm text-neutral-400">
          {progress < 30 && 'Downloading AI model...'}
          {progress >= 30 && progress < 70 && 'Loading model into memory...'}
          {progress >= 70 && progress < 100 && 'Almost ready...'}
          {progress === 100 && 'Model loaded successfully!'}
        </p>

        <p className="text-center text-xs text-neutral-500">
          ~150MB one-time download • Cached for future use
        </p>
      </div>
    </div>
  );
}
