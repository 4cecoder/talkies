'use client';

import { useState, useEffect } from 'react';
import { Mic, MicOff, Copy, CheckCircle, AlertCircle, Sparkles } from 'lucide-react';
import { useWhisperTranscription } from '@/app/hooks/useWhisperTranscription';
import { ModelLoadingProgress } from './ModelLoadingProgress';
import { AudioWaveform } from './AudioWaveform';

export function LiveTranscriptionDemo() {
  const {
    transcript,
    isListening,
    isLoading,
    isModelLoaded,
    loadingProgress,
    error,
    startListening,
    stopListening,
    wordCount,
    wpm,
    audioLevel,
  } = useWhisperTranscription();

  const [copied, setCopied] = useState(false);
  const [recordingTime, setRecordingTime] = useState(0);
  const MAX_DEMO_TIME = 60; // 1 minute demo limit

  // Timer for recording duration
  useEffect(() => {
    let interval: NodeJS.Timeout;

    if (isListening) {
      interval = setInterval(() => {
        setRecordingTime((prev) => {
          if (prev >= MAX_DEMO_TIME) {
            stopListening();
            return MAX_DEMO_TIME;
          }
          return prev + 1;
        });
      }, 1000);
    } else {
      setRecordingTime(0);
    }

    return () => {
      if (interval) clearInterval(interval);
    };
  }, [isListening, stopListening]);

  // Copy transcript to clipboard
  const copyTranscript = async () => {
    if (!transcript) return;

    try {
      await navigator.clipboard.writeText(transcript);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch (err) {
      console.error('Failed to copy:', err);
    }
  };

  // Format time as MM:SS
  const formatTime = (seconds: number): string => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  return (
    <div className="relative mx-auto max-w-4xl">
      {/* Main Card */}
      <div className="group relative overflow-hidden rounded-2xl border border-white/10 bg-gradient-to-br from-white/5 to-white/[0.02] p-8 backdrop-blur-xl">
        {/* Gradient Glow Effect */}
        <div className="absolute -inset-1 -z-10 rounded-2xl bg-gradient-to-r from-purple-600 via-pink-600 to-blue-600 opacity-20 blur-2xl transition-opacity group-hover:opacity-30" />

        {/* Header */}
        <div className="mb-6 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="flex h-10 w-10 items-center justify-center rounded-full bg-gradient-to-r from-purple-500 to-pink-500">
              <Sparkles className="h-5 w-5 text-white" />
            </div>
            <div>
              <h3 className="text-lg font-semibold text-white">Live Transcription Demo</h3>
              <p className="text-sm text-neutral-400">
                Powered by AI on YOUR device • 100% private
              </p>
            </div>
          </div>

          {isListening && (
            <div className="flex items-center gap-2 rounded-full bg-red-500/20 px-3 py-1">
              <div className="h-2 w-2 animate-pulse rounded-full bg-red-500" />
              <span className="text-sm font-medium text-red-300">{formatTime(recordingTime)}</span>
            </div>
          )}
        </div>

        {/* Loading State */}
        {isLoading && (
          <div className="py-12">
            <ModelLoadingProgress progress={loadingProgress} />
          </div>
        )}

        {/* Error State */}
        {error && (
          <div className="mb-6 flex items-center gap-3 rounded-lg bg-red-500/10 p-4 text-red-300">
            <AlertCircle className="h-5 w-5 flex-shrink-0" />
            <div>
              <p className="font-medium">Error</p>
              <p className="text-sm text-red-300/80">{error}</p>
            </div>
          </div>
        )}

        {/* Main Content - Only show when model is loaded or not loading */}
        {!isLoading && (
          <>
            {/* Audio Waveform */}
            <div className="mb-6">
              <AudioWaveform audioLevel={audioLevel} isListening={isListening} />
            </div>

            {/* Transcript Display */}
            <div className="relative mb-6 min-h-[120px] rounded-lg border border-white/10 bg-black/20 p-4">
              {transcript ? (
                <div className="space-y-3">
                  <p className="text-base leading-relaxed text-white">{transcript}</p>

                  {/* Copy Button */}
                  <button
                    onClick={copyTranscript}
                    className="flex items-center gap-2 rounded-lg bg-white/10 px-3 py-1.5 text-sm text-white transition-colors hover:bg-white/20"
                  >
                    {copied ? (
                      <>
                        <CheckCircle className="h-4 w-4 text-green-400" />
                        <span className="text-green-400">Copied!</span>
                      </>
                    ) : (
                      <>
                        <Copy className="h-4 w-4" />
                        <span>Copy</span>
                      </>
                    )}
                  </button>
                </div>
              ) : (
                <p className="text-neutral-400">
                  {isListening
                    ? 'Listening... Start speaking to see transcription.'
                    : isModelLoaded
                    ? 'Click the microphone to start recording.'
                    : 'Click "Try Live Demo" to load the AI model.'}
                </p>
              )}
            </div>

            {/* Stats */}
            {transcript && (
              <div className="mb-6 grid grid-cols-2 gap-4">
                <div className="rounded-lg bg-white/5 p-3">
                  <p className="text-xs text-neutral-400">Words</p>
                  <p className="text-2xl font-bold text-white">{wordCount}</p>
                </div>
                <div className="rounded-lg bg-white/5 p-3">
                  <p className="text-xs text-neutral-400">Words per Minute</p>
                  <p className="text-2xl font-bold text-white">{wpm}</p>
                </div>
              </div>
            )}

            {/* Controls */}
            <div className="flex flex-col items-center gap-4">
              {/* Record Button */}
              {!isListening ? (
                <button
                  onClick={startListening}
                  disabled={isLoading}
                  className="group relative inline-flex items-center justify-center gap-3 overflow-hidden rounded-full bg-gradient-to-r from-purple-500 to-pink-500 px-8 py-4 text-base font-semibold text-white shadow-lg shadow-purple-500/50 transition-all hover:scale-105 hover:shadow-xl hover:shadow-purple-500/60 disabled:cursor-not-allowed disabled:opacity-50 disabled:hover:scale-100"
                >
                  <Mic className="h-5 w-5" />
                  {isModelLoaded ? 'Start Recording' : 'Try Live Demo'}
                </button>
              ) : (
                <button
                  onClick={stopListening}
                  className="group relative inline-flex items-center justify-center gap-3 overflow-hidden rounded-full bg-red-500 px-8 py-4 text-base font-semibold text-white shadow-lg shadow-red-500/50 transition-all hover:scale-105 hover:shadow-xl hover:shadow-red-500/60"
                >
                  <MicOff className="h-5 w-5" />
                  Stop Recording
                </button>
              )}

              {/* Demo Limit Notice */}
              {recordingTime >= MAX_DEMO_TIME && (
                <div className="rounded-lg bg-gradient-to-r from-purple-500/20 to-pink-500/20 p-4 text-center">
                  <p className="text-sm font-medium text-white">Demo time limit reached!</p>
                  <p className="mt-1 text-xs text-neutral-300">
                    Upgrade for unlimited transcription
                  </p>
                  <button className="mt-3 rounded-lg bg-gradient-to-r from-purple-500 to-pink-500 px-4 py-2 text-sm font-semibold text-white transition-transform hover:scale-105">
                    Get Pro Version
                  </button>
                </div>
              )}

              {/* Features */}
              <div className="mt-4 flex flex-wrap items-center justify-center gap-4 text-xs text-neutral-400">
                <div className="flex items-center gap-1.5">
                  <CheckCircle className="h-3.5 w-3.5 text-green-400" />
                  <span>100% Private</span>
                </div>
                <div className="flex items-center gap-1.5">
                  <CheckCircle className="h-3.5 w-3.5 text-green-400" />
                  <span>Runs Offline</span>
                </div>
                <div className="flex items-center gap-1.5">
                  <CheckCircle className="h-3.5 w-3.5 text-green-400" />
                  <span>No Cloud Processing</span>
                </div>
                <div className="flex items-center gap-1.5">
                  <CheckCircle className="h-3.5 w-3.5 text-green-400" />
                  <span>100+ Languages</span>
                </div>
              </div>
            </div>
          </>
        )}
      </div>

      {/* Privacy Badge */}
      <div className="mt-4 text-center">
        <p className="text-xs text-neutral-500">
          Your voice never leaves your device • Model cached locally after first download
        </p>
      </div>
    </div>
  );
}
