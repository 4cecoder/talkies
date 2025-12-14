using System;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using Talkies.Windows.Services;

namespace Talkies.Windows.Plugins
{
    /// <summary>
    /// Sentiment analysis powered by LM Studio (preferred) with a local heuristic fallback.
    /// </summary>
    public class SentimentAnalyzerPlugin : ITextEnhancer
    {
        private readonly SentimentAnalysisService _sentimentService = new();
        private readonly HttpClient _http = new() { Timeout = TimeSpan.FromSeconds(30) };
        private string _endpoint = "http://127.0.0.1:1234";

        private const string DefaultModel = "smollm2-1.7b-instruct-uncensored";
        private const string SystemPrompt = """
You are a strict sentiment classifier for short messages and transcripts. Follow these rules exactly:

1) Decide the sentiment and output ONLY one line in the format:
Result: <very positive 🤩 | positive 🙂 | neutral 😐 | negative 🙁 | very negative 🤬>

2) Do NOT add explanations, confidence, or extra words.

3) Examples:
   - "I love this!" -> Result: very positive 🤩
   - "Looks fine." -> Result: neutral 😐
   - "I'm a bit worried" -> Result: negative 🙁
   - "This is awful" -> Result: very negative 🤬
   - "Sure, that works" -> Result: positive 🙂

Respond with the Result line only.
""";

        public string Name => "Sentiment Analysis";
        public bool IsEnabled { get; set; } = true;
        public string Endpoint
        {
            get => _endpoint;
            set => _endpoint = string.IsNullOrWhiteSpace(value) ? "http://127.0.0.1:1234" : value.TrimEnd('/');
        }

        public string Model { get; set; } = DefaultModel;
        public string SystemPromptOverride { get; set; } = SystemPrompt;

        /// <summary>
        /// Analyzes the sentiment of the given text and appends a short summary.
        /// </summary>
        public async Task<string> EnhanceAsync(string text)
        {
            if (string.IsNullOrWhiteSpace(text))
                return text;

            try
            {
                var result = await AnalyzeWithLmStudioAsync(text) ?? _sentimentService.Analyze(text);
                var sentimentText = $"\n\n[Sentiment Analysis: {result.Label} {result.Emoji} ({Math.Round(result.Score, 2)})]";
                return text + sentimentText;
            }
            catch (Exception ex)
            {
                Logger.Error($"Sentiment analysis failed: {ex.Message}");
                return text + "\n\n[Sentiment Analysis: unavailable]";
            }
        }

        /// <summary>
        /// Gets detailed sentiment information for display or debugging.
        /// </summary>
        public SentimentResult GetSentimentInfo(string text)
        {
            if (string.IsNullOrWhiteSpace(text))
            {
                return new SentimentResult { Score = 0, Label = "Neutral", Emoji = "😐" };
            }

            try
            {
                return _sentimentService.Analyze(text);
            }
            catch
            {
                return new SentimentResult { Score = 0, Label = "Neutral", Emoji = "😐" };
            }
        }

        private async Task<SentimentResult?> AnalyzeWithLmStudioAsync(string text)
        {
            try
            {
                var payload = new
                {
                    model = Model,
                    messages = new[]
                    {
                        new { role = "system", content = string.IsNullOrWhiteSpace(SystemPromptOverride) ? SystemPrompt : SystemPromptOverride },
                        new { role = "user", content = text }
                    },
                    temperature = 0.0,
                    max_tokens = 128,
                    stream = false
                };

                var content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json");
                var response = await _http.PostAsync($"{Endpoint}/v1/chat/completions", content);
                if (!response.IsSuccessStatusCode)
                {
                    Logger.Warn($"LM Studio sentiment request failed: {response.StatusCode}");
                    return null;
                }

                var json = await response.Content.ReadAsStringAsync();
                using var doc = JsonDocument.Parse(json);
                var message = doc.RootElement
                    .GetProperty("choices")[0]
                    .GetProperty("message")
                    .GetProperty("content")
                    .GetString();

                if (string.IsNullOrWhiteSpace(message))
                {
                    return null;
                }

                var parsed = ParseResult(message);
                return parsed ?? _sentimentService.Analyze(text);
            }
            catch (Exception ex)
            {
                Logger.Warn($"LM Studio sentiment unavailable: {ex.Message}");
                return null;
            }
        }

        private static SentimentResult? ParseResult(string content)
        {
            var match = Regex.Match(content, @"Result:\s*(.+)", RegexOptions.IgnoreCase);
            if (!match.Success) return null;

            var labelRaw = match.Groups[1].Value.Trim().ToLowerInvariant();

            return labelRaw switch
            {
                { } s when s.StartsWith("very positive") => new SentimentResult { Label = "Very Positive", Emoji = "🤩", Score = 0.8 },
                { } s when s.StartsWith("positive") => new SentimentResult { Label = "Positive", Emoji = "🙂", Score = 0.3 },
                { } s when s.StartsWith("neutral") => new SentimentResult { Label = "Neutral", Emoji = "😐", Score = 0.0 },
                { } s when s.StartsWith("very negative") => new SentimentResult { Label = "Very Negative", Emoji = "🤬", Score = -0.8 },
                { } s when s.StartsWith("negative") => new SentimentResult { Label = "Negative", Emoji = "🙁", Score = -0.3 },
                _ => null
            };
        }
    }
}
