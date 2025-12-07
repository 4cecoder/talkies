using System;
using System.Collections.Generic;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Shapes;

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
        private readonly LinearGradientBrush _gradientBrush;

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

            // Create gradient brush for bars (blue to cyan)
            _gradientBrush = new LinearGradientBrush
            {
                StartPoint = new Point(0, 0),
                EndPoint = new Point(0, 1),
                GradientStops = new GradientStopCollection
                {
                    new GradientStop(Color.FromRgb(102, 179, 255), 0.0),    // Blue
                    new GradientStop(Color.FromRgb(0, 204, 255), 1.0)       // Cyan
                }
            };

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
                var bar = new Rectangle
                {
                    Width = BarWidth,
                    Height = Math.Max(barHeight, 0.5), // Ensure minimum height for visibility
                    Fill = _gradientBrush.Clone(),
                    Opacity = 0.7 + (0.3 * (float)i / BarCount) // Fade in left to right
                };

                Canvas.SetLeft(bar, x);
                Canvas.SetTop(bar, barY);

                WaveformCanvas.Children.Add(bar);
            }
        }
    }
}
