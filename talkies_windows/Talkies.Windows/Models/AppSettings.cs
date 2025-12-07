using System.Collections.Generic;

namespace Talkies.Windows.Models
{
    public class CustomPrompt
    {
        public string Name { get; set; } = string.Empty;
        public string Prompt { get; set; } = string.Empty;
    }

    public class AppSettings
    {
        public string Model { get; set; } = "tiny";
        public string Language { get; set; } = "auto";
        public string? MicrophoneId { get; set; }
        public bool EnhanceEnabled { get; set; }
        public string OllamaUrl { get; set; } = "http://localhost:11434";
        public string OllamaModel { get; set; } = "llama3.2";
        public bool TtsEnabled { get; set; }
        public bool InsertEnabled { get; set; }
        public bool VadEnabled { get; set; } = true;
        public bool FilterEnabled { get; set; } = true;

        // LLM Provider Settings
        public string SelectedLlmProvider { get; set; } = "Ollama";
        public string LlmEndpoint { get; set; } = "http://localhost:11434";
        public string? SelectedLlmModelName { get; set; }
        public string SelectedEnhancementMode { get; set; } = "Grammar";

        // User-defined enhancement prompts
        public List<CustomPrompt> CustomPrompts { get; set; } = new();
    }
}
