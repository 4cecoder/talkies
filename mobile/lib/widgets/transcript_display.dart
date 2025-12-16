import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/audio_recorder_service.dart';

/// Display for transcription segments with modern design
/// Redesigned with smooth animations and modern UI
class TranscriptDisplay extends StatelessWidget {
  const TranscriptDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final audioService = context.watch<AudioRecorderService>();

    if (audioService.segments.isEmpty) {
      return const _EmptyTranscriptState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: audioService.segments.length,
      itemBuilder: (context, index) {
        final segment = audioService.segments[index];
        return _TranscriptSegmentTile(
          index: index,
          text: segment.text,
          timestamp: segment.timestamp,
          onCopy: () {
            Clipboard.setData(ClipboardData(text: segment.text));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Copied to clipboard'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 1),
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptyTranscriptState extends StatelessWidget {
  const _EmptyTranscriptState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mic_none_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No transcription yet',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }
}

class _TranscriptSegmentTile extends StatefulWidget {
  final int index;
  final String text;
  final String timestamp;
  final VoidCallback onCopy;

  const _TranscriptSegmentTile({
    required this.index,
    required this.text,
    required this.timestamp,
    required this.onCopy,
  });

  @override
  State<_TranscriptSegmentTile> createState() => _TranscriptSegmentTileState();
}

class _TranscriptSegmentTileState extends State<_TranscriptSegmentTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    // Stagger the animation based on index
    Future.delayed(Duration(milliseconds: widget.index * 50), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onLongPress: widget.onCopy,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with segment number and timestamp
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                Theme.of(context).colorScheme.secondary,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${widget.index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.timestamp,
                            style: TextStyle(
                              fontFamily: 'SF Mono',
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: widget.onCopy,
                          icon: Icon(
                            Icons.copy_rounded,
                            size: 18,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          tooltip: 'Copy',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Transcript text
                    Text(
                      widget.text,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            height: 1.5,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
