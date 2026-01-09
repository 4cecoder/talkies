'use client';

import { useEffect, useRef } from 'react';

interface AudioWaveformProps {
  audioLevel: number;
  isListening: boolean;
}

export function AudioWaveform({ audioLevel, isListening }: AudioWaveformProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const width = canvas.width;
    const height = canvas.height;

    // Clear canvas
    ctx.clearRect(0, 0, width, height);

    if (!isListening) {
      // Draw idle state
      ctx.strokeStyle = 'rgba(168, 85, 247, 0.3)'; // purple-400 with opacity
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(0, height / 2);
      ctx.lineTo(width, height / 2);
      ctx.stroke();
      return;
    }

    // Draw waveform bars
    const barCount = 40;
    const barWidth = width / barCount;
    const maxBarHeight = height * 0.8;

    for (let i = 0; i < barCount; i++) {
      // Create wave effect
      const phase = (i / barCount) * Math.PI * 2;
      const waveOffset = Math.sin(phase + Date.now() * 0.005) * 0.3;

      // Height based on audio level + wave effect
      const barHeight = (audioLevel + waveOffset) * maxBarHeight;

      const x = i * barWidth;
      const y = (height - barHeight) / 2;

      // Gradient from purple to pink
      const gradient = ctx.createLinearGradient(0, 0, width, 0);
      gradient.addColorStop(0, 'rgba(168, 85, 247, 0.8)'); // purple-400
      gradient.addColorStop(1, 'rgba(236, 72, 153, 0.8)'); // pink-400

      ctx.fillStyle = gradient;
      ctx.fillRect(x + 1, y, barWidth - 2, barHeight);
    }
  }, [audioLevel, isListening]);

  return (
    <canvas
      ref={canvasRef}
      width={600}
      height={80}
      className="w-full rounded-lg"
    />
  );
}
