'use client';

import { useState, useRef, useCallback, useEffect } from 'react';
import { pipeline, type AutomaticSpeechRecognitionPipeline } from '@xenova/transformers';

export interface TranscriptionResult {
  text: string;
  chunks: Array<{
    text: string;
    timestamp: [number, number];
  }>;
}

export interface UseWhisperTranscriptionReturn {
  transcript: string;
  isListening: boolean;
  isLoading: boolean;
  isModelLoaded: boolean;
  loadingProgress: number;
  error: string | null;
  startListening: () => Promise<void>;
  stopListening: () => void;
  wordCount: number;
  wpm: number;
  audioLevel: number;
}

export function useWhisperTranscription(): UseWhisperTranscriptionReturn {
  const [transcript, setTranscript] = useState('');
  const [isListening, setIsListening] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [isModelLoaded, setIsModelLoaded] = useState(false);
  const [loadingProgress, setLoadingProgress] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [wordCount, setWordCount] = useState(0);
  const [wpm, setWpm] = useState(0);
  const [audioLevel, setAudioLevel] = useState(0);

  const transcriber = useRef<AutomaticSpeechRecognitionPipeline | null>(null);
  const mediaRecorder = useRef<MediaRecorder | null>(null);
  const audioChunks = useRef<Blob[]>([]);
  const startTime = useRef<number>(0);
  const audioContext = useRef<AudioContext | null>(null);
  const analyser = useRef<AnalyserNode | null>(null);
  const animationFrame = useRef<number | undefined>(undefined);

  // Load Whisper model
  const loadModel = useCallback(async () => {
    if (transcriber.current) return;

    try {
      setIsLoading(true);
      setError(null);
      setLoadingProgress(0);

      // Load the Whisper Base model with progress tracking
      transcriber.current = await pipeline(
        'automatic-speech-recognition',
        'Xenova/whisper-base',
        {
          progress_callback: (progress: { progress: number; status: string }) => {
            if (progress.progress) {
              setLoadingProgress(Math.round(progress.progress));
            }
          },
        }
      );

      setIsModelLoaded(true);
      setLoadingProgress(100);
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to load model';
      setError(errorMessage);
      console.error('Model loading error:', err);
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Analyze audio level for visualization
  const analyzeAudio = useCallback(() => {
    if (!analyser.current) return;

    const dataArray = new Uint8Array(analyser.current.frequencyBinCount);
    analyser.current.getByteFrequencyData(dataArray);

    // Calculate average volume
    const average = dataArray.reduce((sum, value) => sum + value, 0) / dataArray.length;
    setAudioLevel(average / 255); // Normalize to 0-1

    animationFrame.current = requestAnimationFrame(analyzeAudio);
  }, []);

  // Start listening
  const startListening = useCallback(async () => {
    if (isListening) return;

    try {
      setError(null);

      // Load model if not already loaded
      if (!transcriber.current) {
        await loadModel();
      }

      if (!transcriber.current) {
        throw new Error('Model not loaded');
      }

      // Request microphone permission
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });

      // Set up audio context for visualization
      audioContext.current = new (window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext)();
      const source = audioContext.current.createMediaStreamSource(stream);
      analyser.current = audioContext.current.createAnalyser();
      analyser.current.fftSize = 256;
      source.connect(analyser.current);

      // Start analyzing audio
      analyzeAudio();

      // Set up MediaRecorder
      mediaRecorder.current = new MediaRecorder(stream);
      audioChunks.current = [];

      mediaRecorder.current.ondataavailable = (event) => {
        if (event.data.size > 0) {
          audioChunks.current.push(event.data);
        }
      };

      mediaRecorder.current.onstop = async () => {
        const audioBlob = new Blob(audioChunks.current, { type: 'audio/wav' });

        try {
          // Convert blob to ArrayBuffer
          const arrayBuffer = await audioBlob.arrayBuffer();

          // Transcribe audio
          // Convert audio data to Float32Array at 16kHz sampling rate
          const result = await transcriber.current!(
            new Float32Array(arrayBuffer)
          ) as TranscriptionResult;

          setTranscript(result.text);

          // Calculate word count and WPM
          const words = result.text.trim().split(/\s+/).length;
          setWordCount(words);

          const duration = (Date.now() - startTime.current) / 1000 / 60; // minutes
          setWpm(Math.round(words / duration));
        } catch (err) {
          const errorMessage = err instanceof Error ? err.message : 'Transcription failed';
          setError(errorMessage);
          console.error('Transcription error:', err);
        }

        // Clean up
        stream.getTracks().forEach(track => track.stop());
        if (animationFrame.current) {
          cancelAnimationFrame(animationFrame.current);
        }
        setAudioLevel(0);
      };

      // Start recording
      mediaRecorder.current.start();
      setIsListening(true);
      startTime.current = Date.now();
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to start recording';
      setError(errorMessage);
      console.error('Recording error:', err);
    }
  }, [isListening, loadModel, analyzeAudio]);

  // Stop listening
  const stopListening = useCallback(() => {
    if (!isListening || !mediaRecorder.current) return;

    try {
      mediaRecorder.current.stop();
      setIsListening(false);
    } catch (err) {
      console.error('Stop recording error:', err);
    }
  }, [isListening]);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (mediaRecorder.current && isListening) {
        mediaRecorder.current.stop();
      }
      if (animationFrame.current) {
        cancelAnimationFrame(animationFrame.current);
      }
      if (audioContext.current) {
        audioContext.current.close();
      }
    };
  }, [isListening]);

  return {
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
  };
}
