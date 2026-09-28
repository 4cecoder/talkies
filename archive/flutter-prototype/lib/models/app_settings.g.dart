// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppSettings _$AppSettingsFromJson(Map<String, dynamic> json) => AppSettings(
      selectedMicrophone: json['selectedMicrophone'] as String? ?? 'default',
      transcriptionModel: json['transcriptionModel'] as String? ?? 'base',
      language: json['language'] as String? ?? 'auto',
      enableLlmEnhancement: json['enableLlmEnhancement'] as bool? ?? false,
      llmProvider: json['llmProvider'] as String? ?? 'ollama',
      llmEndpoint: json['llmEndpoint'] as String? ?? 'http://localhost:11434',
      llmModel: json['llmModel'] as String? ?? '',
      enhancementMode: json['enhancementMode'] as String? ?? 'grammar',
      lastExportFormat: json['lastExportFormat'] as String? ?? 'txt',
      darkMode: json['darkMode'] as bool? ?? true,
      showWaveform: json['showWaveform'] as bool? ?? true,
    );

Map<String, dynamic> _$AppSettingsToJson(AppSettings instance) =>
    <String, dynamic>{
      'selectedMicrophone': instance.selectedMicrophone,
      'transcriptionModel': instance.transcriptionModel,
      'language': instance.language,
      'enableLlmEnhancement': instance.enableLlmEnhancement,
      'llmProvider': instance.llmProvider,
      'llmEndpoint': instance.llmEndpoint,
      'llmModel': instance.llmModel,
      'enhancementMode': instance.enhancementMode,
      'lastExportFormat': instance.lastExportFormat,
      'darkMode': instance.darkMode,
      'showWaveform': instance.showWaveform,
    };
