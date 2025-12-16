import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Live waveform visualization widget with smooth animations
/// Creates an audio visualizer effect similar to professional recording apps
class LiveWaveform extends StatefulWidget {
  final double audioLevel;
  final bool isActive;
  final int barCount;
  final Color? activeColor;
  final Color? inactiveColor;

  const LiveWaveform({
    super.key,
    required this.audioLevel,
    this.isActive = true,
    this.barCount = 40,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  State<LiveWaveform> createState() => _LiveWaveformState();
}

class _LiveWaveformState extends State<LiveWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<double> _barHeights;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _barHeights = List.generate(widget.barCount, (_) => 0.2);
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    )..addListener(_updateBars);

    if (widget.isActive) {
      _controller.repeat();
    }
  }

  void _updateBars() {
    if (!widget.isActive) return;

    setState(() {
      for (var i = 0; i < widget.barCount; i++) {
        // Create smooth transitions with some randomness based on audio level
        final targetHeight = 0.1 +
            (widget.audioLevel * 0.8) +
            (_random.nextDouble() * 0.15 * widget.audioLevel);
        _barHeights[i] = _barHeights[i] + (targetHeight - _barHeights[i]) * 0.3;
      }
    });
  }

  @override
  void didUpdateWidget(LiveWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
      // Animate bars back to minimum
      setState(() {
        for (var i = 0; i < _barHeights.length; i++) {
          _barHeights[i] = 0.1;
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.activeColor ??
        Theme.of(context).colorScheme.primary;
    final inactiveColor = widget.inactiveColor ??
        Theme.of(context).colorScheme.outline.withOpacity(0.3);

    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = (constraints.maxWidth - (widget.barCount - 1) * 2) /
            widget.barCount;
        final maxHeight = constraints.maxHeight;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(widget.barCount, (index) {
            final normalizedIndex = (index - widget.barCount / 2).abs() /
                (widget.barCount / 2);
            final heightMultiplier = 1.0 - (normalizedIndex * 0.3);
            final height =
                (_barHeights[index] * maxHeight * heightMultiplier).clamp(
              4.0,
              maxHeight,
            );

            return AnimatedContainer(
              duration: const Duration(milliseconds: 50),
              width: barWidth.clamp(2.0, 6.0),
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(barWidth / 2),
                gradient: widget.isActive
                    ? LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          activeColor,
                          activeColor.withOpacity(0.6),
                        ],
                      )
                    : null,
                color: widget.isActive ? null : inactiveColor,
              ),
            );
          }),
        );
      },
    );
  }
}

/// Compact waveform for displaying in lists or cards
class CompactWaveform extends StatelessWidget {
  final List<double> amplitudes;
  final Color? color;
  final double height;

  const CompactWaveform({
    super.key,
    required this.amplitudes,
    this.color,
    this.height = 32,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = color ?? Theme.of(context).colorScheme.primary;
    final barCount = amplitudes.length.clamp(1, 50);

    return SizedBox(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(barCount, (index) {
          final amplitude = amplitudes[index].clamp(0.0, 1.0);
          final barHeight = 4 + (amplitude * (height - 8));

          return Container(
            width: 3,
            height: barHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1.5),
              color: barColor.withOpacity(0.4 + (amplitude * 0.6)),
            ),
          );
        }),
      ),
    );
  }
}
