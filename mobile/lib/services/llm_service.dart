import 'package:dio/dio.dart';

/// LLM service for text enhancement
/// Based on OllamaEnhancer.cs and LmStudioProvider.cs from Windows implementation
class LlmService {
  final Dio _dio = Dio();

  /// Enhance text using configured LLM provider
  Future<String> enhanceText({
    required String text,
    required String endpoint,
    required String model,
    required String mode,
  }) async {
    final prompt = _buildPrompt(text, mode);
    
    try {
      final response = await _dio.post(
        '$endpoint/api/generate',
        data: {
          'model': model,
          'prompt': prompt,
          'stream': false,
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      if (response.statusCode == 200) {
        return response.data['response'] as String;
      } else {
        throw Exception('LLM request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('LLM enhancement failed: $e');
    }
  }

  /// Fetch available models from LLM provider
  Future<List<String>> fetchModels(String endpoint) async {
    try {
      final response = await _dio.get(
        '$endpoint/api/tags',
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200) {
        final models = (response.data['models'] as List)
            .map((m) => m['name'] as String)
            .toList();
        return models;
      } else {
        throw Exception('Failed to fetch models');
      }
    } catch (e) {
      throw Exception('Error fetching models: $e');
    }
  }

  /// Build prompt based on enhancement mode
  String _buildPrompt(String text, String mode) {
    switch (mode.toLowerCase()) {
      case 'grammar':
        return 'Fix the grammar, spelling, and punctuation in the following text. '
            'Keep the meaning unchanged. Only output the corrected text:\n\n$text';
      
      case 'concise':
        return 'Make the following text more concise while preserving key information. '
            'Only output the shortened text:\n\n$text';
      
      case 'detailed':
        return 'Expand the following text with more detail and explanation. '
            'Only output the expanded text:\n\n$text';
      
      case 'creative':
        return 'Rephrase the following text in a more creative and engaging way. '
            'Only output the rephrased text:\n\n$text';
      
      default:
        return 'Improve the following text:\n\n$text';
    }
  }
}
