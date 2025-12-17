import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/audio_recorder_service.dart';
import '../services/settings_service.dart';
import '../widgets/animated_record_button.dart';
import '../widgets/live_waveform.dart';
import '../widgets/glassmorphic_card.dart';
import '../widgets/transcript_display.dart';
import 'settings_screen.dart';

/// Main home screen with recording interface
/// Redesigned with SuperWhisper-inspired glassmorphic UI
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioService = context.watch<AudioRecorderService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: _buildAppBar(context, audioService),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF0F0F1A),
                      const Color(0xFF1A1A2E),
                      const Color(0xFF16213E),
                    ]
                  : [
                      const Color(0xFFF0F2F5),
                      const Color(0xFFE8EAF0),
                      const Color(0xFFF5F7FA),
                    ],
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // Stats section
                  _buildStatsSection(context, audioService),

                  // Main content area (transcript or empty state)
                  Expanded(
                    child: _buildMainContent(context, audioService),
                  ),

                  // Recording controls section
                  _buildControlsSection(context, audioService),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    AudioRecorderService audioService,
  ) {
    return AppBar(
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: audioService.isRecording
            ? Row(
                key: const ValueKey('recording'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDuration(audioService.duration),
                    style: const TextStyle(
                      fontFamily: 'SF Mono',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : const Text(
                key: ValueKey('title'),
                'Talkies',
              ),
      ),
      actions: [
        if (audioService.segments.isNotEmpty && !audioService.isRecording)
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Clear transcript',
            onPressed: () => _showClearConfirmation(context),
          ),
        IconButton(
          icon: const Icon(Icons.tune_rounded),
          tooltip: 'Settings',
          onPressed: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const SettingsScreen(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1.0, 0.0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatsSection(
    BuildContext context,
    AudioRecorderService audioService,
  ) {
    if (!audioService.isRecording && audioService.segments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: GlassmorphicCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
              icon: Icons.timer_outlined,
              value: _formatDuration(audioService.duration),
              label: 'Duration',
            ),
            _buildDivider(context),
            _StatItem(
              icon: Icons.text_fields_rounded,
              value: '${audioService.totalWords}',
              label: 'Words',
            ),
            _buildDivider(context),
            _StatItem(
              icon: Icons.speed_rounded,
              value: '${audioService.wordsPerMinute}',
              label: 'WPM',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: Theme.of(context).dividerColor.withOpacity(0.3),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    AudioRecorderService audioService,
  ) {
    if (audioService.segments.isEmpty) {
      return _buildEmptyState(context, audioService);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassmorphicCard(
        padding: EdgeInsets.zero,
        child: const TranscriptDisplay(),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    AudioRecorderService audioService,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated microphone icon
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                Colors.white.withOpacity(0.1),
                                Colors.white.withOpacity(0.05),
                              ]
                            : [
                                Colors.black.withOpacity(0.05),
                                Colors.black.withOpacity(0.02),
                              ],
                      ),
                    ),
                    child: Icon(
                      Icons.mic_none_rounded,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Ready to Record',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to start transcribing',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Feature hints
            _buildFeatureHint(
              context,
              icon: Icons.language_rounded,
              text: '100+ languages supported',
            ),
            const SizedBox(height: 12),
            _buildFeatureHint(
              context,
              icon: Icons.lock_outline_rounded,
              text: 'On-device processing, fully private',
            ),
            const SizedBox(height: 12),
            _buildFeatureHint(
              context,
              icon: Icons.auto_awesome_rounded,
              text: 'AI enhancement available',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureHint(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      ],
    );
  }

  Widget _buildControlsSection(
    BuildContext context,
    AudioRecorderService audioService,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Live waveform when recording
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: audioService.isRecording ? 60 : 0,
            child: audioService.isRecording
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: LiveWaveform(
                      audioLevel: audioService.audioLevel,
                      isActive: audioService.isRecording && !audioService.isPaused,
                      barCount: 48,
                      activeColor: const Color(0xFFEF4444),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Main controls row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pause/Resume button (when recording)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: audioService.isRecording ? 1.0 : 0.0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: audioService.isRecording ? 56 : 0,
                  child: audioService.isRecording
                      ? IconButton.filled(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            if (audioService.isPaused) {
                              audioService.resumeRecording();
                            } else {
                              audioService.pauseRecording();
                            }
                          },
                          icon: Icon(
                            audioService.isPaused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.surfaceContainerHighest,
                            foregroundColor: Theme.of(context).colorScheme.onSurface,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),

              const SizedBox(width: 16),

              // Main record button
              AnimatedRecordButton(
                isRecording: audioService.isRecording,
                isPaused: audioService.isPaused,
                audioLevel: audioService.audioLevel,
                onTap: () async {
                  if (audioService.isRecording) {
                    await audioService.stopRecording();
                  } else {
                    try {
                      await audioService.startRecording();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  }
                },
              ),

              const SizedBox(width: 16),

              // Export button (when not recording and has content)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: !audioService.isRecording && audioService.segments.isNotEmpty
                    ? 1.0
                    : 0.0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: (!audioService.isRecording && audioService.segments.isNotEmpty)
                      ? 56
                      : 0,
                  child: (!audioService.isRecording && audioService.segments.isNotEmpty)
                      ? IconButton.filled(
                          onPressed: () => _showExportSheet(context),
                          icon: const Icon(Icons.share_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),

              // Placeholder for symmetry when recording
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: audioService.isRecording ? 56 : 0,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Transcript'),
        content: const Text(
          'Are you sure you want to clear the current transcript? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<AudioRecorderService>().clearTranscription();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showExportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ExportBottomSheet(),
    );
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final secs = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      ],
    );
  }
}

class _ExportBottomSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassmorphicCard(
      margin: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'Export Transcript',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 20),
          _ExportOption(
            icon: Icons.subtitles_rounded,
            title: 'SRT Subtitles',
            subtitle: 'Standard subtitle format',
            format: 'srt',
          ),
          _ExportOption(
            icon: Icons.closed_caption_rounded,
            title: 'WebVTT',
            subtitle: 'Web video text tracks',
            format: 'vtt',
          ),
          _ExportOption(
            icon: Icons.text_snippet_rounded,
            title: 'Plain Text',
            subtitle: 'Simple text with timestamps',
            format: 'txt',
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ExportOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String format;

  const _ExportOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () async {
        Navigator.pop(context);
        final audioService = context.read<AudioRecorderService>();

        try {
          await context.read<SettingsService>().exportAndShare(
            segments: audioService.segments,
            format: format,
          );
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Export failed: $e'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
    );
  }
}
