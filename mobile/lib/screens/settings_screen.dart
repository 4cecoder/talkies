import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/llm_service.dart';
import '../widgets/glassmorphic_card.dart';

/// Settings screen with modern design
/// Redesigned with grouping and visual hierarchy
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _llmService = LlmService();
  List<String> _availableModels = [];
  bool _loadingModels = false;

  @override
  Widget build(BuildContext context) {
    final settingsService = context.watch<SettingsService>();
    final settings = settingsService.settings;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
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
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Transcription Section
              _buildSectionHeader(context, 'Transcription', Icons.mic_rounded),
              const SizedBox(height: 12),
              GlassmorphicCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.memory_rounded,
                      title: 'Model',
                      subtitle: settings.transcriptionModel,
                      onTap: () => _showModelPicker(context),
                    ),
                    _buildDivider(context),
                    _SettingsTile(
                      icon: Icons.language_rounded,
                      title: 'Language',
                      subtitle: settings.language == 'auto'
                          ? 'Auto-detect'
                          : settings.language.toUpperCase(),
                      onTap: () => _showLanguagePicker(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // LLM Enhancement Section
              _buildSectionHeader(
                  context, 'AI Enhancement', Icons.auto_awesome_rounded),
              const SizedBox(height: 12),
              GlassmorphicCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SettingsToggle(
                      icon: Icons.psychology_rounded,
                      title: 'Enable Enhancement',
                      subtitle: 'Improve transcripts with AI',
                      value: settings.enableLlmEnhancement,
                      onChanged: (value) {
                        settingsService.setLlmEnhancement(value);
                      },
                    ),
                    if (settings.enableLlmEnhancement) ...[
                      _buildDivider(context),
                      _SettingsTile(
                        icon: Icons.cloud_rounded,
                        title: 'Provider',
                        subtitle: _formatProvider(settings.llmProvider),
                        onTap: () => _showProviderPicker(context),
                      ),
                      _buildDivider(context),
                      _SettingsTile(
                        icon: Icons.link_rounded,
                        title: 'Endpoint',
                        subtitle: settings.llmEndpoint,
                        onTap: () => _showEndpointEditor(context),
                      ),
                      _buildDivider(context),
                      _SettingsTile(
                        icon: Icons.smart_toy_rounded,
                        title: 'Model',
                        subtitle: settings.llmModel.isEmpty
                            ? 'Not selected'
                            : settings.llmModel,
                        trailing: _loadingModels
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : null,
                        onTap:
                            _loadingModels ? null : () => _fetchAndShowModels(context),
                      ),
                      _buildDivider(context),
                      _SettingsTile(
                        icon: Icons.tune_rounded,
                        title: 'Enhancement Mode',
                        subtitle: _formatMode(settings.enhancementMode),
                        onTap: () => _showEnhancementModePicker(context),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Export Section
              _buildSectionHeader(context, 'Export', Icons.upload_file_rounded),
              const SizedBox(height: 12),
              GlassmorphicCard(
                padding: EdgeInsets.zero,
                child: _SettingsTile(
                  icon: Icons.description_rounded,
                  title: 'Default Format',
                  subtitle: settings.lastExportFormat.toUpperCase(),
                  onTap: () => _showFormatPicker(context),
                ),
              ),

              const SizedBox(height: 28),

              // Appearance Section
              _buildSectionHeader(
                  context, 'Appearance', Icons.palette_rounded),
              const SizedBox(height: 12),
              GlassmorphicCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SettingsToggle(
                      icon: Icons.dark_mode_rounded,
                      title: 'Dark Mode',
                      subtitle: 'Use dark color scheme',
                      value: settings.darkMode,
                      onChanged: (value) {
                        settingsService.setDarkMode(value);
                      },
                    ),
                    _buildDivider(context),
                    _SettingsToggle(
                      icon: Icons.graphic_eq_rounded,
                      title: 'Show Waveform',
                      subtitle: 'Display audio visualization',
                      value: settings.showWaveform,
                      onChanged: (value) {
                        settingsService.updateSettings(
                          settings.copyWith(showWaveform: value),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // About Section
              _buildSectionHeader(context, 'About', Icons.info_outline_rounded),
              const SizedBox(height: 12),
              GlassmorphicCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                Theme.of(context).colorScheme.secondary,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.mic_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Talkies',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Version 1.0.0',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.outline,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Privacy-first voice transcription powered by on-device AI.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      ],
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      indent: 56,
      color: Theme.of(context).dividerColor.withOpacity(0.3),
    );
  }

  String _formatProvider(String provider) {
    switch (provider.toLowerCase()) {
      case 'ollama':
        return 'Ollama';
      case 'lmstudio':
        return 'LM Studio';
      default:
        return provider;
    }
  }

  String _formatMode(String mode) {
    switch (mode.toLowerCase()) {
      case 'grammar':
        return 'Grammar & Spelling';
      case 'concise':
        return 'Make Concise';
      case 'detailed':
        return 'Add Detail';
      case 'creative':
        return 'Creative Rephrase';
      default:
        return mode;
    }
  }

  void _showModelPicker(BuildContext context) {
    final models = [
      ('tiny', 'Tiny', 'Fastest, lower accuracy'),
      ('base', 'Base', 'Balanced speed/accuracy'),
      ('small', 'Small', 'Good accuracy'),
      ('medium', 'Medium', 'High accuracy'),
      ('large', 'Large', 'Best accuracy, slowest'),
    ];
    final settingsService = context.read<SettingsService>();
    final current = settingsService.settings.transcriptionModel;

    _showOptionSheet(
      context: context,
      title: 'Transcription Model',
      options: models.map((m) => _OptionItem(
            value: m.$1,
            title: m.$2,
            subtitle: m.$3,
            isSelected: current == m.$1,
          )).toList(),
      onSelect: (value) {
        settingsService.setTranscriptionModel(value);
      },
    );
  }

  void _showLanguagePicker(BuildContext context) {
    final languages = [
      ('auto', 'Auto-detect', 'Automatically detect language'),
      ('en', 'English', ''),
      ('es', 'Spanish', 'Español'),
      ('fr', 'French', 'Français'),
      ('de', 'German', 'Deutsch'),
      ('it', 'Italian', 'Italiano'),
      ('pt', 'Portuguese', 'Português'),
      ('ja', 'Japanese', '日本語'),
      ('zh', 'Chinese', '中文'),
      ('ko', 'Korean', '한국어'),
    ];
    final settingsService = context.read<SettingsService>();
    final current = settingsService.settings.language;

    _showOptionSheet(
      context: context,
      title: 'Language',
      options: languages.map((l) => _OptionItem(
            value: l.$1,
            title: l.$2,
            subtitle: l.$3,
            isSelected: current == l.$1,
          )).toList(),
      onSelect: (value) {
        settingsService.setLanguage(value);
      },
    );
  }

  void _showProviderPicker(BuildContext context) {
    final providers = [
      ('ollama', 'Ollama', 'Local AI with Ollama'),
      ('lmstudio', 'LM Studio', 'OpenAI-compatible endpoint'),
    ];
    final settingsService = context.read<SettingsService>();
    final current = settingsService.settings.llmProvider;

    _showOptionSheet(
      context: context,
      title: 'LLM Provider',
      options: providers.map((p) => _OptionItem(
            value: p.$1,
            title: p.$2,
            subtitle: p.$3,
            isSelected: current == p.$1,
          )).toList(),
      onSelect: (value) {
        settingsService.setLlmProvider(value);
        final endpoint =
            value == 'ollama' ? 'http://localhost:11434' : 'http://127.0.0.1:1234';
        settingsService.setLlmEndpoint(endpoint);
      },
    );
  }

  void _showEndpointEditor(BuildContext context) {
    final settingsService = context.read<SettingsService>();
    final controller = TextEditingController(
      text: settingsService.settings.llmEndpoint,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: GlassmorphicCard(
          margin: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LLM Endpoint',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Endpoint URL',
                  hintText: 'http://localhost:11434',
                ),
                keyboardType: TextInputType.url,
                autofocus: true,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      settingsService.setLlmEndpoint(controller.text);
                      Navigator.pop(context);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _fetchAndShowModels(BuildContext context) async {
    final settingsService = context.read<SettingsService>();

    setState(() {
      _loadingModels = true;
    });

    try {
      final models = await _llmService.fetchModels(
        settingsService.settings.llmEndpoint,
      );

      setState(() {
        _availableModels = models;
        _loadingModels = false;
      });

      if (!mounted) return;

      _showOptionSheet(
        context: context,
        title: 'Select Model',
        options: _availableModels.isEmpty
            ? [_OptionItem(value: '', title: 'No models found', subtitle: '')]
            : _availableModels
                .map((m) => _OptionItem(
                      value: m,
                      title: m,
                      subtitle: '',
                      isSelected: m == settingsService.settings.llmModel,
                    ))
                .toList(),
        onSelect: (value) {
          if (value.isNotEmpty) {
            settingsService.setLlmModel(value);
          }
        },
      );
    } catch (e) {
      setState(() {
        _loadingModels = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showEnhancementModePicker(BuildContext context) {
    final modes = [
      ('grammar', 'Grammar & Spelling', 'Fix errors, improve punctuation'),
      ('concise', 'Make Concise', 'Shorten while preserving meaning'),
      ('detailed', 'Add Detail', 'Expand with more information'),
      ('creative', 'Creative Rephrase', 'Rewrite in an engaging way'),
    ];
    final settingsService = context.read<SettingsService>();
    final current = settingsService.settings.enhancementMode;

    _showOptionSheet(
      context: context,
      title: 'Enhancement Mode',
      options: modes.map((m) => _OptionItem(
            value: m.$1,
            title: m.$2,
            subtitle: m.$3,
            isSelected: current == m.$1,
          )).toList(),
      onSelect: (value) {
        settingsService.setEnhancementMode(value);
      },
    );
  }

  void _showFormatPicker(BuildContext context) {
    final formats = [
      ('srt', 'SRT', 'Standard subtitle format'),
      ('vtt', 'WebVTT', 'Web video text tracks'),
      ('txt', 'Plain Text', 'Simple text with timestamps'),
    ];
    final settingsService = context.read<SettingsService>();
    final current = settingsService.settings.lastExportFormat;

    _showOptionSheet(
      context: context,
      title: 'Export Format',
      options: formats.map((f) => _OptionItem(
            value: f.$1,
            title: f.$2,
            subtitle: f.$3,
            isSelected: current == f.$1,
          )).toList(),
      onSelect: (value) {
        settingsService.updateSettings(
          settingsService.settings.copyWith(lastExportFormat: value),
        );
      },
    );
  }

  void _showOptionSheet({
    required BuildContext context,
    required String title,
    required List<_OptionItem> options,
    required void Function(String) onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassmorphicCard(
        margin: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
            ...options.map((option) => ListTile(
                  leading: option.isSelected
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : Icon(
                          Icons.circle_outlined,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  title: Text(
                    option.title,
                    style: TextStyle(
                      fontWeight:
                          option.isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  subtitle:
                      option.subtitle.isNotEmpty ? Text(option.subtitle) : null,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    onSelect(option.value);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _OptionItem {
  final String value;
  final String title;
  final String subtitle;
  final bool isSelected;

  _OptionItem({
    required this.value,
    required this.title,
    required this.subtitle,
    this.isSelected = false,
  });
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(subtitle),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
      ),
      onTap: () => onChanged(!value),
    );
  }
}
