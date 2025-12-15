import 'package:json_annotation/json_annotation.dart';

part 'app_settings.g.dart';

/// Application settings model
/// Inspired by AppSettings in Windows implementation
@JsonSerializable()
class AppSettings {
  // Recording settings
  String selectedMicrophone;
  String transcriptionModel;
  String language;
  
  // LLM Enhancement settings
  bool enableLlmEnhancement;
  String llmProvider; // 'ollama' or 'lmstudio'
  String llmEndpoint;
  String llmModel;
  String enhancementMode; // 'grammar', 'concise', 'detailed', 'creative'
  
  // Export settings
  String lastExportFormat; // 'srt', 'txt', 'vtt'
  
  // UI settings
  bool darkMode;
  bool showWaveform;

  AppSettings({
    this.selectedMicrophone = 'default',
    this.transcriptionModel = 'base',
    this.language = 'auto',
    this.enableLlmEnhancement = false,
    this.llmProvider = 'ollama',
    this.llmEndpoint = 'http://localhost:11434',
    this.llmModel = '',
    this.enhancementMode = 'grammar',
    this.lastExportFormat = 'txt',
    this.darkMode = true,
    this.showWaveform = true,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$AppSettingsToJson(this);

  AppSettings copyWith({
    String? selectedMicrophone,
    String? transcriptionModel,
    String? language,
    bool? enableLlmEnhancement,
    String? llmProvider,
    String? llmEndpoint,
    String? llmModel,
    String? enhancementMode,
    String? lastExportFormat,
    bool? darkMode,
    bool? showWaveform,
  }) {
    return AppSettings(
      selectedMicrophone: selectedMicrophone ?? this.selectedMicrophone,
      transcriptionModel: transcriptionModel ?? this.transcriptionModel,
      language: language ?? this.language,
      enableLlmEnhancement: enableLlmEnhancement ?? this.enableLlmEnhancement,
      llmProvider: llmProvider ?? this.llmProvider,
      llmEndpoint: llmEndpoint ?? this.llmEndpoint,
      llmModel: llmModel ?? this.llmModel,
      enhancementMode: enhancementMode ?? this.enhancementMode,
      lastExportFormat: lastExportFormat ?? this.lastExportFormat,
      darkMode: darkMode ?? this.darkMode,
      showWaveform: showWaveform ?? this.showWaveform,
    );
  }
}
