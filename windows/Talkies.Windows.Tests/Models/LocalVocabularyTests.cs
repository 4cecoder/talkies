using System;
using System.IO;
using System.Text.Json;
using System.Collections.Generic;
using Talkies.Windows.Models;
using Xunit;

namespace Talkies.Windows.Tests.Models;

public class LocalVocabularyTests
{
    [Fact]
    public void Normalize_TrimsAndDeduplicatesCaseInsensitively()
    {
        var normalized = LocalVocabulary.Normalize(new[] { " Talkies ", "talkies", "Qwen3", "", "  ", "S1-mini" });

        Assert.Equal(new[] { "Talkies", "Qwen3", "S1-mini" }, normalized);
    }

    [Fact]
    public void ToPrompt_JoinsNormalizedTerms()
    {
        var prompt = LocalVocabulary.ToPrompt(new List<string> { "  Wispr Flow", "VoiceInk" });

        Assert.Equal("Wispr Flow, VoiceInk", prompt);
    }

    [Fact]
    public void ToPrompt_EmptyVocabularyReturnsEmptyString()
    {
        Assert.Equal(string.Empty, LocalVocabulary.ToPrompt(null));
    }

    [Fact]
    public void ToPrompt_StopsBeforeExceedingThePromptBudget()
    {
        var prompt = LocalVocabulary.ToPrompt(new[] { new string('a', 399), "discarded" });

        Assert.Equal(new string('a', 399), prompt);
    }

    [Fact]
    public void ToPrompt_MatchesSharedCrossPlatformGoldenFixture()
    {
        var fixturePath = Path.Combine(AppContext.BaseDirectory, "Fixtures", "local-vocabulary-golden.json");
        var fixture = JsonSerializer.Deserialize<VocabularyGoldenFixture>(File.ReadAllText(fixturePath), new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        })!;

        foreach (var testCase in fixture.Cases)
        {
            Assert.Equal(testCase.ExpectedPrompt, LocalVocabulary.ToPrompt(testCase.Terms));
        }
    }

    private sealed class VocabularyGoldenFixture
    {
        public VocabularyGoldenFixture() { }
        public List<VocabularyCase> Cases { get; init; } = [];
    }

    private sealed class VocabularyCase
    {
        public VocabularyCase() { }
        public List<string> Terms { get; init; } = [];
        public string ExpectedPrompt { get; init; } = string.Empty;
    }
}
