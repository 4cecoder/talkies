namespace Talkies.Windows.Plugins;

/// <summary>Formats transcripts using the S1-mini Qwen3 chat template.</summary>
public static class S1MiniPrompt
{
    public const string SystemPrompt = "You are a text normalizer for speech-to-text transcripts. The input begins with a control line specifying the styling, structure, and context settings; clean the transcript to match those settings and output only the cleaned text.";

    public static string Render(string transcript, string style = "semi-formal", string structure = "prose", string context = "general")
    {
        ArgumentNullException.ThrowIfNull(transcript);
        return $"<|im_start|>system\n{SystemPrompt}<|im_end|>\n<|im_start|>user\n[Styling: {style}] [Structure: {structure}] [Context: {context}]\n{transcript}<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n\n";
    }
}
