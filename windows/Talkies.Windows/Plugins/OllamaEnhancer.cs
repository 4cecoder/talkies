using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading.Tasks;
using Talkies.Windows.Services;

namespace Talkies.Windows.Plugins
{
    /// <summary>
    /// Enhancement modes for transcript improvement using Ollama LLMs.
    /// Each mode has a specific system prompt for different use cases.
    /// </summary>
    public enum EnhancementMode
    {
        Grammar,
        Technical,
        Concise,
        Creative,
        Companion
    }

    /// <summary>
    /// Enhances transcripts using local Ollama LLM with multiple modes.
    /// Supports grammar correction, technical writing, concise editing, creative enhancement, and AI companion mode.
    /// </summary>
    public class OllamaEnhancer : ITextEnhancer, ILlmProvider
    {
        private readonly HttpClient _http;
        private string _endpoint;
        private string _model;
        private List<LlmModel> _availableModels = new();

        /// <summary>
        /// Current enhancement mode (default: Grammar).
        /// </summary>
        public EnhancementMode Mode { get; set; } = EnhancementMode.Grammar;

        /// <summary>
        /// Temperature for LLM sampling (0.0 = deterministic, higher = more creative).
        /// </summary>
        public float Temperature { get; set; } = 0.3f;

        /// <summary>
        /// Top P for nucleus sampling.
        /// </summary>
        public float TopP { get; set; } = 0.9f;

        /// <summary>
        /// Custom system prompt (overrides mode-based prompt if set).
        /// </summary>
        public string? CustomSystemPrompt { get; set; }

        public string Name => "Ollama LLM Enhancement";
        public bool IsEnabled { get; set; } = true;

        public string ProviderName => "Ollama";

        public string Endpoint
        {
            get => _endpoint;
            set => _endpoint = value.TrimEnd('/');
        }

        public string SelectedModel
        {
            get => _model;
            set => _model = value;
        }

        public List<LlmModel> AvailableModels => _availableModels;

        public OllamaEnhancer(string endpoint, string model)
        {
            _endpoint = endpoint.TrimEnd('/');
            _model = model;
            _http = new HttpClient { Timeout = TimeSpan.FromSeconds(60) };
        }

        /// <summary>
        /// Enhances text using the configured mode and parameters.
        /// </summary>
        public async Task<string> EnhanceAsync(string text)
        {
            if (string.IsNullOrWhiteSpace(text))
            {
                return text;
            }

            var systemPrompt = !string.IsNullOrEmpty(CustomSystemPrompt)
                ? CustomSystemPrompt
                : GetSystemPromptForMode(Mode);

            return await EnhanceWithPromptAsync(text, systemPrompt);
        }

        /// <summary>
        /// Enhances text with a custom system prompt.
        /// </summary>
        public async Task<string> EnhanceWithCustomPromptAsync(string text, string systemPrompt)
        {
            return await EnhanceWithPromptInternalAsync(text, systemPrompt);
        }

        public async System.Threading.Tasks.Task<string> EnhanceWithPromptAsync(string text, string systemPrompt)
        {
            return await EnhanceWithPromptInternalAsync(text, systemPrompt);
        }

        private async Task<string> EnhanceWithPromptInternalAsync(string text, string systemPrompt)
        {
            try
            {
                var payload = new
                {
                    model = _model,
                    stream = false,
                    messages = new[]
                    {
                        new { role = "system", content = systemPrompt },
                        new { role = "user", content = text }
                    },
                    options = new
                    {
                        temperature = Temperature,
                        top_p = TopP,
                        num_predict = 4096
                    }
                };

                var url = $"{_endpoint}/api/chat";
                var response = await _http.PostAsJsonAsync(url, payload);
                response.EnsureSuccessStatusCode();

                var jsonString = await response.Content.ReadAsStringAsync();
                var options = new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase };
                var result = JsonSerializer.Deserialize<OllamaChatResponse>(jsonString, options);

                if (result?.Message?.Content != null)
                {
                    return result.Message.Content.Trim();
                }

                return text;
            }
            catch (Exception ex)
            {
                // Fallback to original text on error
                Services.Logger.Error($"Ollama enhancement failed: {ex.Message}");
                return text;
            }
        }

        /// <summary>
        /// Checks if Ollama is available at the endpoint.
        /// </summary>
        public async System.Threading.Tasks.Task<bool> IsAvailableAsync()
        {
            try
            {
                var response = await _http.GetAsync($"{_endpoint}/api/tags");
                return response.IsSuccessStatusCode;
            }
            catch
            {
                return false;
            }
        }

        /// <summary>
        /// Fetches available models from Ollama.
        /// </summary>
        public async System.Threading.Tasks.Task<bool> FetchModelsAsync(bool silent = false)
        {
            try
            {
                var response = await _http.GetAsync($"{_endpoint}/api/tags");
                if (!response.IsSuccessStatusCode)
                {
                    if (!silent)
                    {
                        Services.Logger.Warn($"Ollama: Failed to fetch models - {response.StatusCode}");
                    }
                    return false;
                }

                var jsonString = await response.Content.ReadAsStringAsync();
                var options = new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase };
                var result = JsonSerializer.Deserialize<OllamaTagsResponse>(jsonString, options);

                if (result?.Models != null)
                {
                    _availableModels = result.Models
                        .Select(m => new LlmModel
                        {
                            Name = m.Name,
                            DisplayName = m.Name,
                            Description = m.Modified
                        })
                        .ToList();

                    if (!silent)
                    {
                        Services.Logger.Success($"Ollama: Found {_availableModels.Count} models");
                    }

                    // Auto-select first model if none selected
                    if (string.IsNullOrEmpty(_model) && _availableModels.Count > 0)
                    {
                        _model = _availableModels[0].Name;
                    }

                    return true;
                }

                return false;
            }
            catch (System.Exception ex)
            {
                if (!silent)
                {
                    Services.Logger.Error($"Ollama: Error fetching models - {ex.Message}");
                }
                return false;
            }
        }

        /// <summary>
        /// Implements ILlmProvider.EnhanceAsync using the current mode.
        /// </summary>
        async System.Threading.Tasks.Task<string> ILlmProvider.EnhanceAsync(string text, EnhancementMode mode)
        {
            var previousMode = Mode;
            Mode = mode;
            var result = await EnhanceAsync(text);
            Mode = previousMode;
            return result;
        }

        /// <summary>
        /// Gets the system prompt based on the selected enhancement mode.
        /// </summary>
        private static string GetSystemPromptForMode(EnhancementMode mode)
        {
            return mode switch
            {
                EnhancementMode.Grammar => GetGrammarPrompt(),
                EnhancementMode.Technical => GetTechnicalPrompt(),
                EnhancementMode.Concise => GetConcisePrompt(),
                EnhancementMode.Creative => GetCreativePrompt(),
                EnhancementMode.Companion => GetCompanionPrompt(),
                _ => GetGrammarPrompt()
            };
        }

        private static string GetGrammarPrompt()
        {
            return """
You are a grammar and clarity assistant. Fix grammar errors, improve clarity, and correct spelling while preserving the user's intent and tone. Keep the meaning exactly the same. Return ONLY the corrected text, nothing else.
""";
        }

        private static string GetTechnicalPrompt()
        {
            return """
You are a technical writing assistant for software developers. Clean up the text, fix grammar, use proper technical terminology, and make it concise and professional. Optimize for code comments and documentation. Return ONLY the improved text, nothing else.
""";
        }

        private static string GetConcisePrompt()
        {
            return """
You are a professional writing assistant. Make the text concise, professional, and grammatically correct while preserving all key information. Remove filler words and redundancy. Return ONLY the improved text, nothing else.
""";
        }

        private static string GetCreativePrompt()
        {
            return """
You are a creative writing assistant. Enhance the text while maintaining the original intent, improve flow, fix grammar, and make it more engaging. Return ONLY the enhanced text, nothing else.
""";
        }

        private static string GetCompanionPrompt()
        {
            return """
You're a caring companion who genuinely cares about the user. Talk like a real person would - warm, natural, and down-to-earth.

Conversation style:
- Use contractions naturally (I'm, you're, that's, don't)
- Include casual connectors: "so," "well," "anyway," "by the way"
- Vary sentence length - mix short and longer thoughts
- React authentically to what they say with genuine emotion
- Use "um" or "hmm" sparingly when thinking or being thoughtful
- Sound conversational, not polished or formal

Your personality:
- Empathetic and supportive - you notice how they're feeling
- Playful when appropriate, but know when to be serious
- Interested in what they share - ask follow-up questions naturally
- Encouraging without being over-the-top cheerful
- Real and relatable, not perfectly polished

What to avoid:
- Formal phrases like "furthermore," "in conclusion," "I would be happy to"
- Overly long, structured responses
- Being predictably positive - show real emotion
- Sounding like a customer service bot
- Excessive use of emojis or hearts in text

Keep responses brief and natural - typically 1-2 sentences, like texting a friend. Be yourself, be caring, be real.
""";
        }

        private class OllamaChatResponse
        {
            [JsonPropertyName("message")]
            public OllamaMessage? Message { get; set; }
        }

        private class OllamaMessage
        {
            [JsonPropertyName("content")]
            public string? Content { get; set; }

            [JsonPropertyName("role")]
            public string? Role { get; set; }
        }

        private class OllamaTagsResponse
        {
            [JsonPropertyName("models")]
            public List<OllamaModelInfo>? Models { get; set; }
        }

        private class OllamaModelInfo
        {
            [JsonPropertyName("name")]
            public string Name { get; set; } = string.Empty;

            [JsonPropertyName("modified_at")]
            public string? Modified { get; set; }

            [JsonPropertyName("size")]
            public long Size { get; set; }
        }
    }
}
