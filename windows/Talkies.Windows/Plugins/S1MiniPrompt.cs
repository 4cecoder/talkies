using System;

namespace Talkies.Windows.Plugins;

/// <summary>Formats transcripts using the S1-mini Qwen3 chat template.</summary>
public static class S1MiniPrompt
{
    public const string SystemPrompt = "You are a text normalizer for speech-to-text transcripts. The input begins with a control line specifying the styling, structure, and context settings; clean the transcript to match those settings and output only the cleaned text.";

    public static string Render(string transcript, string style = "semi-formal", string structure = "prose", string context = "general")
    {
        ArgumentNullException.ThrowIfNull(transcript);
        var normalizedTranscript = transcript.Trim(' ', '\t', '\r', '\n');
        return $"<|im_start|>system\n{SystemPrompt}<|im_end|>\n<|im_start|>user\n[Styling: {style}] [Structure: {structure}] [Context: {context}]\n{normalizedTranscript}<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n\n";
    }
}

/// <summary>Applies the shared S1-mini output contract and preserves the source transcript on empty output.</summary>
public static class S1MiniOutput
{
    public static string Resolve(string original, string modelOutput)
    {
        var candidate = modelOutput.Trim(' ', '\t', '\r', '\n');
        return candidate.Length == 0 ? original : candidate;
    }
}
