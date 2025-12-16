import 'dart:ui';
import 'package:flutter/material.dart';

/// A glassmorphic card widget with frosted glass effect
/// Inspired by SuperWhisper's minimal, premium design aesthetic
class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Gradient? gradient;
  final Border? border;

  const GlassmorphicCard({
    super.key,
    required this.child,
    this.blur = 10,
    this.opacity = 0.1,
    this.borderRadius,
    this.padding,
    this.margin,
    this.gradient,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultRadius = BorderRadius.circular(24);

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: borderRadius ?? defaultRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding ?? const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: gradient ??
                  LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            Colors.white.withOpacity(opacity),
                            Colors.white.withOpacity(opacity * 0.5),
                          ]
                        : [
                            Colors.white.withOpacity(0.8),
                            Colors.white.withOpacity(0.6),
                          ],
                  ),
              borderRadius: borderRadius ?? defaultRadius,
              border: border ??
                  Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.15)
                        : Colors.white.withOpacity(0.5),
                    width: 1.5,
                  ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A subtle glow effect behind widgets
class GlowEffect extends StatelessWidget {
  final Widget child;
  final Color color;
  final double blurRadius;
  final double spread;

  const GlowEffect({
    super.key,
    required this.child,
    this.color = const Color(0xFF8B5CF6),
    this.blurRadius = 40,
    this.spread = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 100 + spread,
          height: 100 + spread,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: blurRadius,
                spreadRadius: spread / 2,
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}
