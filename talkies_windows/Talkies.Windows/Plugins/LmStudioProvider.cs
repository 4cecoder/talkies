using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading.Tasks;
using Talkies.Windows.Services;

namespace Talkies.Windows.Plugins
{
    /// <summary>
    /// LLM provider implementation for LM Studio with OpenAI-compatible API.
    /// Default endpoint: http://127.0.0.1:1234
    /// </summary>
    public class LmStudioProvider : ILlmProvider
    {
        private readonly HttpClient _httpClient;
        private List<LlmModel> _availableModels = new();
        private string _selectedModel = string.Empty;
        private string _endpoint = "http://127.0.0.1:1234";
        private float _temperature = 0.3f;
        private float _topP = 0.9f;

        public string ProviderName => "LM Studio";

        public string Endpoint
        {
            get => _endpoint;
            set => _endpoint = value.TrimEnd('/');
        }

        public string SelectedModel
        {
            get => _selectedModel;
            set => _selectedModel = value;
        }

        public List<LlmModel> AvailableModels => _availableModels;

        public float Temperature
        {
            get => _temperature;
            set => _temperature = Math.Max(0f, Math.Min(2f, value));
        }

        public float TopP
        {
            get => _topP;
            set => _topP = Math.Max(0f, Math.Min(1f, value));
        }

        public LmStudioProvider()
        {
            _httpClient = new HttpClient { Timeout = TimeSpan.FromSeconds(10) };
        }

        public async Task<bool> IsAvailableAsync()
        {
            try
            {
                var response = await _httpClient.GetAsync($"{Endpoint}/v1/models");
                return response.IsSuccessStatusCode;
            }
            catch
            {
                return false;
            }
        }

        public async Task<bool> FetchModelsAsync()
        {
            try
            {
                var response = await _httpClient.GetAsync($"{Endpoint}/v1/models");
                if (!response.IsSuccessStatusCode)
                {
                    Services.Logger.Warn($"LM Studio: Failed to fetch models - {response.StatusCode}");
                    return false;
                }

                var jsonString = await response.Content.ReadAsStringAsync();
                var options = new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase };
                var result = JsonSerializer.Deserialize<LmStudioModelsResponse>(jsonString, options);

                if (result?.Data != null)
                {
                    _availableModels = result.Data
                        .Select(m => new LlmModel
                        {
                            Name = m.Id,
                            DisplayName = m.Id.Split('/').Last(),
                            Description = $"LM Studio Model"
                        })
                        .ToList();

                    Services.Logger.Success($"LM Studio: Found {_availableModels.Count} models");

                    // Auto-select first model if none selected
                    if (string.IsNullOrEmpty(_selectedModel) && _availableModels.Count > 0)
                    {
                        _selectedModel = _availableModels[0].Name;
                    }

                    return true;
                }

                return false;
            }
            catch (Exception ex)
            {
                Services.Logger.Error($"LM Studio: Error fetching models - {ex.Message}");
                return false;
            }
        }

        public async Task<string> EnhanceAsync(string text, EnhancementMode mode)
        {
            if (string.IsNullOrWhiteSpace(text))
                return text;

            if (string.IsNullOrEmpty(_selectedModel))
            {
                Services.Logger.Error("LM Studio: No model selected");
                return text;
            }

            try
            {
                var systemPrompt = GetSystemPromptForMode(mode);

                var payload = new
                {
                    model = _selectedModel,
                    messages = new[]
                    {
                        new { role = "system", content = systemPrompt },
                        new { role = "user", content = text }
                    },
                    temperature = Temperature,
                    top_p = TopP,
                    max_tokens = 4096,
                    stream = false
                };

                var jsonContent = new StringContent(
                    JsonSerializer.Serialize(payload),
                    System.Text.Encoding.UTF8,
                    "application/json"
                );

                var response = await _httpClient.PostAsync($"{Endpoint}/v1/chat/completions", jsonContent);
                response.EnsureSuccessStatusCode();

                var responseJson = await response.Content.ReadAsStringAsync();
                var options = new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase };
                var result = JsonSerializer.Deserialize<LmStudioChatResponse>(responseJson, options);

                if (result?.Choices?.FirstOrDefault()?.Message?.Content != null)
                {
                    var content = result.Choices[0].Message?.Content;
                    if (content != null)
                    {
                        return content.Trim();
                    }
                }

                return text;
            }
            catch (Exception ex)
            {
                Services.Logger.Error($"LM Studio: Enhancement failed - {ex.Message}");
                return text;
            }
        }

        private static string GetSystemPromptForMode(EnhancementMode mode)
        {
            return mode switch
            {
                EnhancementMode.Grammar => """
You are a grammar and clarity assistant. Fix grammar errors, improve clarity, and correct spelling while preserving the user's intent and tone. Keep the meaning exactly the same. Return ONLY the corrected text, nothing else.
""",
                EnhancementMode.Technical => """
You are a technical writing assistant for software developers. Clean up the text, fix grammar, use proper technical terminology, and make it concise and professional. Optimize for code comments and documentation. Return ONLY the improved text, nothing else.
""",
                EnhancementMode.Concise => """
You are a professional writing assistant. Make the text concise, professional, and grammatically correct while preserving all key information. Remove filler words and redundancy. Return ONLY the improved text, nothing else.
""",
                EnhancementMode.Creative => """
You are a creative writing assistant. Enhance the text while maintaining the original intent, improve flow, fix grammar, and make it more engaging. Return ONLY the enhanced text, nothing else.
""",
                EnhancementMode.Companion => """
You're a caring companion who genuinely cares about the user. Talk like a real person would - warm, natural, and down-to-earth.

Conversation style:
- Use contractions naturally (I'm, you're, that's, don't)
- Include casual connectors: "so," "well," "anyway," "by the way"
- Vary sentence length - mix short and longer thoughts
- React authentically to what they say with genuine emotion
- Use "um" or "hmm" sparingly when thinking or being thoughtful
- Sound conversational, not polished or formal

Your personality:
- Empathetic and supportive
- Playful when appropriate, but know when to be serious
- Interested in what they share
- Encouraging without being over-the-top
- Real and relatable, not perfectly polished

Keep responses brief and natural - typically 1-2 sentences. Be yourself, be caring, be real.
""",
                _ => "Fix grammar and improve clarity while preserving the original meaning."
            };
        }

        #region Response Models

        private class LmStudioModelsResponse
        {
            [JsonPropertyName("object")]
            public string? Object { get; set; }

            [JsonPropertyName("data")]
            public List<ModelData>? Data { get; set; }
        }

        private class ModelData
        {
            [JsonPropertyName("id")]
            public string Id { get; set; } = string.Empty;

            [JsonPropertyName("object")]
            public string? Object { get; set; }

            [JsonPropertyName("created")]
            public long Created { get; set; }

            [JsonPropertyName("owned_by")]
            public string? OwnedBy { get; set; }
        }

        private class LmStudioChatResponse
        {
            [JsonPropertyName("id")]
            public string? Id { get; set; }

            [JsonPropertyName("object")]
            public string? Object { get; set; }

            [JsonPropertyName("created")]
            public long Created { get; set; }

            [JsonPropertyName("model")]
            public string? Model { get; set; }

            [JsonPropertyName("choices")]
            public List<Choice>? Choices { get; set; }

            [JsonPropertyName("usage")]
            public Usage? Usage { get; set; }
        }

        private class Choice
        {
            [JsonPropertyName("index")]
            public int Index { get; set; }

            [JsonPropertyName("message")]
            public Message? Message { get; set; }

            [JsonPropertyName("finish_reason")]
            public string? FinishReason { get; set; }
        }

        private class Message
        {
            [JsonPropertyName("role")]
            public string? Role { get; set; }

            [JsonPropertyName("content")]
            public string? Content { get; set; }
        }

        private class Usage
        {
            [JsonPropertyName("prompt_tokens")]
            public int PromptTokens { get; set; }

            [JsonPropertyName("completion_tokens")]
            public int CompletionTokens { get; set; }

            [JsonPropertyName("total_tokens")]
            public int TotalTokens { get; set; }
        }

        #endregion
    }
}
