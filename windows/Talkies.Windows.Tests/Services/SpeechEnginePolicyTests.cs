using Newtonsoft.Json;
using Talkies.Windows.Models;
using Talkies.Windows.Services;
using Xunit;

namespace Talkies.Windows.Tests.Services;

public sealed class SpeechEnginePolicyTests
{
    [Theory]
    [InlineData("en", true)]
    [InlineData("EN", true)]
    [InlineData("en-US", true)]
    [InlineData("auto", true)]
    [InlineData("", true)]
    [InlineData(null, true)]
    [InlineData("es", false)]
    [InlineData("zh", false)]
    [InlineData("eng", false)]
    public void IsPhonon2Language_AcceptsEnglishAndUnspecified(string? language, bool expected)
    {
        Assert.Equal(expected, SpeechEnginePolicy.IsPhonon2Language(language));
    }

    [Theory]
    [InlineData(SpeechEngine.Automatic, "en", new[] { "phonon2", "whisper" })]
    [InlineData(SpeechEngine.Automatic, "auto", new[] { "phonon2", "whisper" })]
    [InlineData(SpeechEngine.Automatic, "fr", new[] { "whisper" })]
    [InlineData(SpeechEngine.Phonon2, "en", new[] { "phonon2", "whisper" })]
    [InlineData(SpeechEngine.Phonon2, "pt", new[] { "whisper" })]
    [InlineData(SpeechEngine.Whisper, "en", new[] { "whisper" })]
    public void Order_AlwaysEndsWithWhisper(SpeechEngine engine, string language, string[] expected)
    {
        Assert.Equal(expected, SpeechEnginePolicy.Order(engine, language));
    }

    [Fact]
    public void Settings_DefaultToAutomaticWhenAbsentFromExistingConfig()
    {
        var settings = JsonConvert.DeserializeObject<AppSettings>("{\"Model\":\"base\",\"Language\":\"en\"}");

        Assert.NotNull(settings);
        Assert.Equal(SpeechEngine.Automatic, settings!.SpeechEngine);
    }

    [Fact]
    public void Settings_PersistSpeechEngineByName()
    {
        var json = JsonConvert.SerializeObject(new AppSettings { SpeechEngine = SpeechEngine.Whisper });

        Assert.Contains("\"SpeechEngine\":\"Whisper\"", json, System.StringComparison.Ordinal);
        Assert.Equal(SpeechEngine.Whisper, JsonConvert.DeserializeObject<AppSettings>(json)!.SpeechEngine);
    }
}
