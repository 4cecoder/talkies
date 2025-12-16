import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../models/transcript_segment.dart';
import '../services/export_service.dart';

/// Settings service for persistent configuration
/// Based on SettingsService.cs from Windows implementation
class SettingsService extends ChangeNotifier {
  static const String _settingsKey = 'app_settings';
  late SharedPreferences _prefs;
  late AppSettings _settings;

  AppSettings get settings => _settings;

  SettingsService() {
    _settings = AppSettings();
  }

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      final jsonString = _prefs.getString(_settingsKey);
      if (jsonString != null) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        _settings = AppSettings.fromJson(json);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      _settings = AppSettings();
    }
  }

  Future<void> saveSettings() async {
    try {
      final jsonString = jsonEncode(_settings.toJson());
      await _prefs.setString(_settingsKey, jsonString);
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    _settings = newSettings;
    notifyListeners();
    await saveSettings();
  }

  // Convenience methods for specific settings
  Future<void> setTranscriptionModel(String model) async {
    _settings = _settings.copyWith(transcriptionModel: model);
    notifyListeners();
    await saveSettings();
  }

  Future<void> setLanguage(String language) async {
    _settings = _settings.copyWith(language: language);
    notifyListeners();
    await saveSettings();
  }

  Future<void> setLlmEnhancement(bool enabled) async {
    _settings = _settings.copyWith(enableLlmEnhancement: enabled);
    notifyListeners();
    await saveSettings();
  }

  Future<void> setLlmProvider(String provider) async {
    _settings = _settings.copyWith(llmProvider: provider);
    notifyListeners();
    await saveSettings();
  }

  Future<void> setLlmEndpoint(String endpoint) async {
    _settings = _settings.copyWith(llmEndpoint: endpoint);
    notifyListeners();
    await saveSettings();
  }

  Future<void> setLlmModel(String model) async {
    _settings = _settings.copyWith(llmModel: model);
    notifyListeners();
    await saveSettings();
  }

  Future<void> setEnhancementMode(String mode) async {
    _settings = _settings.copyWith(enhancementMode: mode);
    notifyListeners();
    await saveSettings();
  }

  Future<void> setDarkMode(bool darkMode) async {
    _settings = _settings.copyWith(darkMode: darkMode);
    notifyListeners();
    await saveSettings();
  }

  /// Export and share transcript in the specified format
  Future<void> exportAndShare({
    required List<TranscriptSegment> segments,
    required String format,
  }) async {
    await ExportService.saveAndShare(
      segments: segments,
      format: format,
    );

    // Update last used export format
    _settings = _settings.copyWith(lastExportFormat: format);
    await saveSettings();
  }
}
