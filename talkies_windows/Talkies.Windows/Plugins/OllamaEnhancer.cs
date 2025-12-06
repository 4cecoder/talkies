using System;
using System.Net.Http;
using System.Net.Http.Json;
using System.Text.Json;
using System.Threading.Tasks;

namespace Talkies.Windows.Plugins
{
    public class OllamaEnhancer : ITextEnhancer
    {
        private readonly HttpClient _http;
        private readonly string _endpoint;
        private readonly string _model;

        public OllamaEnhancer(string endpoint, string model)
        {
            _endpoint = endpoint.TrimEnd('/');
            _model = model;
            _http = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
        }

        public string Name => "Ollama";
        public bool IsEnabled { get; set; } = true;

        public async Task<string> EnhanceAsync(string text)
        {
            var payload = new
            {
                model = _model,
                prompt = $"Improve this transcript: {text}"
            };

            var url = $"{_endpoint}/api/generate";
            var res = await _http.PostAsJsonAsync(url, payload);
            res.EnsureSuccessStatusCode();

            var doc = await res.Content.ReadFromJsonAsync<JsonElement>();
            if (doc.TryGetProperty("response", out var resp))
            {
                return resp.GetString() ?? text;
            }
            return text;
        }
    }
}
