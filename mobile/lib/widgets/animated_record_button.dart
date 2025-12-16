import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Animated recording button with pulsing rings and waveform visualization
/// Inspired by SuperWhisper's premium, minimal recording interface
class AnimatedRecordButton extends StatefulWidget {
  final bool isRecording;
  final bool isPaused;
  final double audioLevel;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const AnimatedRecordButton({
    super.key,
    required this.isRecording,
    required this.isPaused,
    required this.audioLevel,
    required this.onTap,
    this.onLongPress,
  });

  @override
  State<AnimatedRecordButton> createState() => _AnimatedRecordButtonState();
}

class _AnimatedRecordButtonState extends State<AnimatedRecordButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse animation for recording state
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Scale animation for tap feedback
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    // Waveform animation
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    if (widget.isRecording && !widget.isPaused) {
      _pulseController.repeat(reverse: true);
      _waveController.repeat();
    }
  }

  @override
  void didUpdateWidget(AnimatedRecordButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isRecording && !widget.isPaused) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
        _waveController.repeat();
      }
    } else {
      _pulseController.stop();
      _pulseController.value = 0;
      _waveController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scaleController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _scaleController.forward();
    HapticFeedback.lightImpact();
  }

  void _handleTapUp(TapUpDetails details) {
    _scaleController.reverse();
  }

  void _handleTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final recordingColor = const Color(0xFFEF4444);

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _pulseAnimation,
          _scaleAnimation,
          _waveController,
        ]),
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow rings (visible when recording)
                  if (widget.isRecording && !widget.isPaused) ...[
                    _buildPulseRing(
                      color: recordingColor,
                      size: 140 * _pulseAnimation.value,
                      opacity: 0.15 * (1.3 - _pulseAnimation.value),
                    ),
                    _buildPulseRing(
                      color: recordingColor,
                      size: 120 * _pulseAnimation.value * 0.9,
                      opacity: 0.2 * (1.3 - _pulseAnimation.value),
                    ),
                  ],

                  // Waveform visualization ring
                  if (widget.isRecording && !widget.isPaused)
                    CustomPaint(
                      size: const Size(130, 130),
                      painter: WaveformPainter(
                        progress: _waveController.value,
                        audioLevel: widget.audioLevel,
                        color: recordingColor,
                      ),
                    ),

                  // Main button
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: widget.isRecording
                            ? [recordingColor, const Color(0xFFF97316)]
                            : [primaryColor, const Color(0xFFEC4899)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (widget.isRecording ? recordingColor : primaryColor)
                              .withOpacity(0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, animation) {
                          return ScaleTransition(
                            scale: animation,
                            child: child,
                          );
                        },
                        child: widget.isRecording
                            ? Container(
                                key: const ValueKey('stop'),
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              )
                            : const Icon(
                                key: ValueKey('mic'),
                                Icons.mic_rounded,
                                color: Colors.white,
                                size: 36,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPulseRing({
    required Color color,
    required double size,
    required double opacity,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withOpacity(opacity),
          width: 2,
        ),
      ),
    );
  }
}

/// Custom painter for waveform visualization around the record button
class WaveformPainter extends CustomPainter {
  final double progress;
  final double audioLevel;
  final Color color;

  WaveformPainter({
    required this.progress,
    required this.audioLevel,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw waveform bars around the circle
    const barCount = 48;
    final amplifiedLevel = (audioLevel * 2).clamp(0.0, 1.0);

    for (var i = 0; i < barCount; i++) {
      final angle = (i / barCount) * 2 * math.pi - math.pi / 2;
      final waveOffset = math.sin((progress * 2 * math.pi) + (i * 0.3));
      final barHeight = 8 + (amplifiedLevel * 15 * (0.5 + waveOffset * 0.5));

      final innerPoint = Offset(
        center.dx + (radius - barHeight) * math.cos(angle),
        center.dy + (radius - barHeight) * math.sin(angle),
      );
      final outerPoint = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      canvas.drawLine(innerPoint, outerPoint, paint);
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.audioLevel != audioLevel;
  }
}
