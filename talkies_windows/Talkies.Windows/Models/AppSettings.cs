namespace Talkies.Windows.Models
{
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
    }
}
