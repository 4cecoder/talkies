import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/llm_service.dart';

/// Settings screen for app configuration
/// Based on SettingsView.swift (macOS) and settings in MainWindow (Windows)
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Transcription Settings
          _buildSection(
            title: 'Transcription',
            children: [
              ListTile(
                title: const Text('Model'),
                subtitle: Text(settings.transcriptionModel),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showModelPicker(context),
              ),
              ListTile(
                title: const Text('Language'),
                subtitle: Text(settings.language),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showLanguagePicker(context),
              ),
            ],
          ),

          // LLM Enhancement Settings
          _buildSection(
            title: 'LLM Enhancement',
            children: [
              SwitchListTile(
                title: const Text('Enable LLM Enhancement'),
                subtitle: const Text('Enhance transcripts with AI'),
                value: settings.enableLlmEnhancement,
                onChanged: (value) {
                  settingsService.setLlmEnhancement(value);
                },
              ),
              if (settings.enableLlmEnhancement) ...[
                ListTile(
                  title: const Text('Provider'),
                  subtitle: Text(settings.llmProvider),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showProviderPicker(context),
                ),
                ListTile(
                  title: const Text('Endpoint'),
                  subtitle: Text(settings.llmEndpoint),
                  trailing: const Icon(Icons.edit),
                  onTap: () => _showEndpointEditor(context),
                ),
                ListTile(
                  title: const Text('Model'),
                  subtitle: Text(
                    settings.llmModel.isEmpty ? 'Not selected' : settings.llmModel,
                  ),
                  trailing: _loadingModels
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _loadingModels ? null : () => _fetchAndShowModels(context),
                ),
                ListTile(
                  title: const Text('Enhancement Mode'),
                  subtitle: Text(settings.enhancementMode),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showEnhancementModePicker(context),
                ),
              ],
            ],
          ),

          // Export Settings
          _buildSection(
            title: 'Export',
            children: [
              ListTile(
                title: const Text('Default Format'),
                subtitle: Text(settings.lastExportFormat.toUpperCase()),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showFormatPicker(context),
              ),
            ],
          ),

          // UI Settings
          _buildSection(
            title: 'Appearance',
            children: [
              SwitchListTile(
                title: const Text('Dark Mode'),
                value: settings.darkMode,
                onChanged: (value) {
                  settingsService.setDarkMode(value);
                },
              ),
              SwitchListTile(
                title: const Text('Show Waveform'),
                subtitle: const Text('Display audio level indicator'),
                value: settings.showWaveform,
                onChanged: (value) {
                  settingsService.updateSettings(
                    settings.copyWith(showWaveform: value),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ...children,
        const Divider(),
      ],
    );
  }

  void _showModelPicker(BuildContext context) {
    final models = ['tiny', 'base', 'small', 'medium', 'large'];
    final settingsService = context.read<SettingsService>();

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Model'),
        children: models
            .map((model) => SimpleDialogOption(
                  onPressed: () {
                    settingsService.setTranscriptionModel(model);
                    Navigator.pop(context);
                  },
                  child: Text(model),
                ))
            .toList(),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    final languages = [
      'auto',
      'en',
      'es',
      'fr',
      'de',
      'it',
      'pt',
      'ja',
      'zh',
    ];
    final settingsService = context.read<SettingsService>();

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Language'),
        children: languages
            .map((lang) => SimpleDialogOption(
                  onPressed: () {
                    settingsService.setLanguage(lang);
                    Navigator.pop(context);
                  },
                  child: Text(lang == 'auto' ? 'Auto-detect' : lang),
                ))
            .toList(),
      ),
    );
  }

  void _showProviderPicker(BuildContext context) {
    final providers = ['ollama', 'lmstudio'];
    final settingsService = context.read<SettingsService>();

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Provider'),
        children: providers
            .map((provider) => SimpleDialogOption(
                  onPressed: () {
                    settingsService.setLlmProvider(provider);
                    // Update default endpoint
                    final endpoint = provider == 'ollama'
                        ? 'http://localhost:11434'
                        : 'http://127.0.0.1:1234';
                    settingsService.setLlmEndpoint(endpoint);
                    Navigator.pop(context);
                  },
                  child: Text(provider),
                ))
            .toList(),
      ),
    );
  }

  void _showEndpointEditor(BuildContext context) {
    final settingsService = context.read<SettingsService>();
    final controller = TextEditingController(
      text: settingsService.settings.llmEndpoint,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('LLM Endpoint'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Endpoint URL',
            hintText: 'http://localhost:11434',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              settingsService.setLlmEndpoint(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
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

      showDialog(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Select Model'),
          children: _availableModels.isEmpty
              ? [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No models found'),
                  ),
                ]
              : _availableModels
                  .map((model) => SimpleDialogOption(
                        onPressed: () {
                          settingsService.setLlmModel(model);
                          Navigator.pop(context);
                        },
                        child: Text(model),
                      ))
                  .toList(),
        ),
      );
    } catch (e) {
      setState(() {
        _loadingModels = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching models: $e')),
      );
    }
  }

  void _showEnhancementModePicker(BuildContext context) {
    final modes = ['grammar', 'concise', 'detailed', 'creative'];
    final settingsService = context.read<SettingsService>();

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Enhancement Mode'),
        children: modes
            .map((mode) => SimpleDialogOption(
                  onPressed: () {
                    settingsService.setEnhancementMode(mode);
                    Navigator.pop(context);
                  },
                  child: Text(mode),
                ))
            .toList(),
      ),
    );
  }

  void _showFormatPicker(BuildContext context) {
    final formats = ['srt', 'txt', 'vtt'];
    final settingsService = context.read<SettingsService>();

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Export Format'),
        children: formats
            .map((format) => SimpleDialogOption(
                  onPressed: () {
                    settingsService.updateSettings(
                      settingsService.settings.copyWith(lastExportFormat: format),
                    );
                    Navigator.pop(context);
                  },
                  child: Text(format.toUpperCase()),
                ))
            .toList(),
      ),
    );
  }
}
