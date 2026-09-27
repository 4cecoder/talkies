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
    public void TryAdd_TrimsTermAndRejectsDuplicatesCaseInsensitively()
    {
        var terms = new List<string> { "Talkies" };

        Assert.True(LocalVocabulary.TryAdd(terms, "  WhisperKit "));
        Assert.False(LocalVocabulary.TryAdd(terms, "WHISPERKIT"));
        Assert.Equal(new[] { "Talkies", "WhisperKit" }, terms);
    }

    [Theory]
    [InlineData("")]
    [InlineData(" \t ")]
    [InlineData("two\nlines")]
    public void TryAdd_RejectsBlankOrMultilineTerm(string candidate)
    {
        var terms = new List<string> { "Talkies" };

        Assert.False(LocalVocabulary.TryAdd(terms, candidate));
        Assert.Equal(new[] { "Talkies" }, terms);
    }

    [Fact]
    public void TryAdd_RejectsTermThatExceedsPromptLimit()
    {
        var terms = new List<string>();

        Assert.False(LocalVocabulary.TryAdd(terms, new string('x', 401)));
        Assert.Empty(terms);
    }

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
