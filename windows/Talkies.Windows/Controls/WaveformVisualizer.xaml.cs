using System;
using System.Collections.Generic;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Shapes;
using System.Windows.Media;
using Color = System.Windows.Media.Color;
using WpfPoint = System.Windows.Point;
using WpfRectangle = System.Windows.Shapes.Rectangle;
using UserControl = System.Windows.Controls.UserControl;

namespace Talkies.Windows.Controls
{
    /// <summary>
    /// Waveform visualizer that displays real-time audio levels as animated bars.
    /// </summary>
    public partial class WaveformVisualizer : UserControl
    {
        private const int BarCount = 40;
        private const int BarWidth = 8;
        private const int BarSpacing = 2;
        private readonly Queue<float> _audioLevels = new();
        private readonly LinearGradientBrush _quietGradient;
        private readonly LinearGradientBrush _activeGradient;
        private bool _isVoiceActive;

        public static readonly DependencyProperty AudioLevelProperty =
            DependencyProperty.Register(
                nameof(AudioLevel),
                typeof(float),
                typeof(WaveformVisualizer),
                new PropertyMetadata(0f, OnAudioLevelChanged));

        public float AudioLevel
        {
            get => (float)GetValue(AudioLevelProperty);
            set => SetValue(AudioLevelProperty, value);
        }

        public WaveformVisualizer()
        {
            InitializeComponent();

            _quietGradient = BuildGradient(Color.FromRgb(102, 179, 255), Color.FromRgb(0, 204, 255)); // blue/cyan
            _activeGradient = BuildGradient(Color.FromRgb(0, 220, 130), Color.FromRgb(120, 255, 170)); // green glow

            Loaded += (s, e) => RedrawWaveform();
            SizeChanged += (s, e) => RedrawWaveform();
        }

        private static void OnAudioLevelChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
        {
            if (d is WaveformVisualizer visualizer && e.NewValue is float level)
            {
                visualizer.UpdateWaveform(level);
            }
        }

        private void UpdateWaveform(float level)
        {
            // Normalize level to 0-1 range
            var normalizedLevel = Math.Min(Math.Max(level, 0f), 1f);

            // Voice activity flag for UX (simple energy threshold)
            _isVoiceActive = normalizedLevel > 0.12f;

            // Add to queue
            _audioLevels.Enqueue(normalizedLevel);

            // Keep only the last BarCount levels
            while (_audioLevels.Count > BarCount)
            {
                _audioLevels.Dequeue();
            }

            RedrawWaveform();
        }

        private void RedrawWaveform()
        {
            if (WaveformCanvas == null)
                return;

            WaveformCanvas.Children.Clear();

            var canvasWidth = WaveformCanvas.ActualWidth;
            var canvasHeight = WaveformCanvas.ActualHeight;

            // If canvas doesn't have a proper size yet, don't draw
            if (canvasWidth <= 0 || canvasHeight <= 0 || _audioLevels.Count == 0)
                return;

            var levels = _audioLevels.ToArray();
            var levelIndex = 0;

            // Draw bars from left to right
            for (int i = 0; i < BarCount; i++)
            {
                var x = i * (BarWidth + BarSpacing) + BarSpacing;

                if (x + BarWidth > canvasWidth)
                    break;

                // Get level for this bar
                float level = 0;
                if (levelIndex < levels.Length)
                {
                    level = levels[levelIndex];
                    levelIndex++;
                }

                // Calculate bar height based on level
                var barHeight = (float)(canvasHeight * 0.9 * level);
                var barY = (canvasHeight - barHeight) / 2;

                // Create rectangle for this bar
            var bar = new WpfRectangle
            {
                Width = BarWidth,
                Height = Math.Max(barHeight, 0.5), // Ensure minimum height for visibility
                Fill = (_isVoiceActive ? _activeGradient : _quietGradient).Clone(),
                Opacity = 0.55 + (0.35 * (float)i / BarCount) // Fade in left to right
                };

                Canvas.SetLeft(bar, x);
                Canvas.SetTop(bar, barY);

                WaveformCanvas.Children.Add(bar);
            }
        }

        public void Clear()
        {
            _audioLevels.Clear();
            WaveformCanvas?.Children.Clear();
        }

        private static LinearGradientBrush BuildGradient(Color top, Color bottom)
        {
            return new LinearGradientBrush
            {
                StartPoint = new WpfPoint(0, 0),
                EndPoint = new WpfPoint(0, 1),
                GradientStops = new GradientStopCollection
                {
                    new GradientStop(top, 0.0),
                    new GradientStop(bottom, 1.0)
                }
            };
        }
    }
}
