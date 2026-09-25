using System;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Animation;

namespace Talkies.Windows.Services
{
    /// <summary>Applies short, consistent motion while honoring the Windows animation preference.</summary>
    public static class UiMotion
    {
        private static readonly TimeSpan EntranceDuration = TimeSpan.FromMilliseconds(190);
        private static readonly TimeSpan ControlDuration = TimeSpan.FromMilliseconds(160);

        /// <summary>Returns a zero duration when the user has disabled Windows client area animations.</summary>
        public static TimeSpan GetDuration(TimeSpan requestedDuration, bool animationsEnabled) =>
            animationsEnabled ? requestedDuration : TimeSpan.Zero;

        /// <summary>Fades and lifts newly shown content into place.</summary>
        public static void FadeIn(FrameworkElement element, double lift = 0)
        {
            var duration = GetDuration(EntranceDuration, SystemParameters.ClientAreaAnimation);
            if (duration == TimeSpan.Zero)
            {
                element.Opacity = 1;
                if (element.RenderTransform is TranslateTransform translate) translate.Y = 0;
                return;
            }

            element.BeginAnimation(UIElement.OpacityProperty, new DoubleAnimation(0, 1, duration)
            {
                EasingFunction = new QuadraticEase { EasingMode = EasingMode.EaseOut }
            });

            if (lift != 0)
            {
                var transform = element.RenderTransform as TranslateTransform ?? new TranslateTransform();
                element.RenderTransform = transform;
                transform.Y = lift;
                transform.BeginAnimation(TranslateTransform.YProperty, new DoubleAnimation(lift, 0, duration)
                {
                    EasingFunction = new QuadraticEase { EasingMode = EasingMode.EaseOut }
                });
            }
        }

        /// <summary>Gives a newly enabled control a small, restrained scale transition.</summary>
        public static void Emphasize(System.Windows.Controls.Control control)
        {
            var duration = GetDuration(ControlDuration, SystemParameters.ClientAreaAnimation);
            if (duration == TimeSpan.Zero) return;

            var transform = control.RenderTransform as ScaleTransform ?? new ScaleTransform(1, 1);
            control.RenderTransform = transform;
            control.RenderTransformOrigin = new Point(0.5, 0.5);
            transform.ScaleX = 0.97;
            transform.ScaleY = 0.97;
            var easing = new QuadraticEase { EasingMode = EasingMode.EaseOut };
            transform.BeginAnimation(ScaleTransform.ScaleXProperty, new DoubleAnimation(0.97, 1, duration) { EasingFunction = easing });
            transform.BeginAnimation(ScaleTransform.ScaleYProperty, new DoubleAnimation(0.97, 1, duration) { EasingFunction = easing });
        }
    }
}
