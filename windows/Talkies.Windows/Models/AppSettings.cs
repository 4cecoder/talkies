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
        public string SelectedLlmProvider { get; set; } = "LM Studio";
        public string LlmEndpoint { get; set; } = "http://127.0.0.1:1234";
        public string? SelectedLlmModelName { get; set; } = "openai/gpt-oss-20b";
        public string SelectedEnhancementMode { get; set; } = "Grammar";

        // User-defined enhancement prompts
        public List<CustomPrompt> CustomPrompts { get; set; } = new();

        // Plugin settings
        public AdvancedTtsSettings AdvancedTts { get; set; } = new();
        public SentimentSettings Sentiment { get; set; } = new();

        // Crash reporting settings
        public bool CrashReportingEnabled { get; set; } = false;
        public string CrashReportingEndpoint { get; set; } = string.Empty;
        public bool CrashReportingPrivacyAccepted { get; set; } = false;

        // Developer team config
        public TalkiesTeamConfig TalkiesTeamConfig { get; set; } = new();
    }

    public class AdvancedTtsSettings
    {
        public bool IsEnabled { get; set; } = true;
        public string SelectedVoice { get; set; } = string.Empty;
        public int Rate { get; set; } = 0;
        public int Pitch { get; set; } = 0;
        public int Volume { get; set; } = 100;
    }

    public class SentimentSettings
    {
        public bool IsEnabled { get; set; } = true;
        public string Endpoint { get; set; } = "http://127.0.0.1:1234";
        public string Model { get; set; } = "lm-kit.sentiment_analysis-tinyllama-1.1b-1t-openorca-en";
    }

    public class TalkiesTeamConfig
    {
        public bool EnableSimulateCrashesModule { get; set; } = false;
    }
}
