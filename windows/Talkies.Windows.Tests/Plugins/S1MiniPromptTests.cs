using Talkies.Windows.Plugins;
using Talkies.Windows.Services;
using Xunit;

namespace Talkies.Windows.Tests.Plugins;

public sealed class S1MiniPromptTests
{
    [Fact]
    public void Render_UsesPinnedQwenChatTemplateAndOptions()
    {
        var prompt = S1MiniPrompt.Render("um I, I think we should go", "casual", "lists", "email");

        Assert.StartsWith("<|im_start|>system\n" + S1MiniPrompt.SystemPrompt + "<|im_end|>\n<|im_start|>user\n", prompt);
        Assert.Contains("[Styling: casual] [Structure: lists] [Context: email]\num I, I think we should go<|im_end|>", prompt);
        Assert.EndsWith("<|im_start|>assistant\n<think>\n\n</think>\n\n", prompt);
    }

    [Fact]
    public void ModelStore_PinsRevisionAndIntegrityMetadata()
    {
        Assert.Equal(40, S1MiniModelStore.Revision.Length);
        Assert.Equal(64, S1MiniModelStore.ModelSha256.Length);
        Assert.Equal("s1-mini-q4_k_m.gguf", S1MiniModelStore.ModelFileName);
        Assert.Equal(484_219_808, S1MiniModelStore.ModelSize);
    }
}
