using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Talkies.Windows.Models;
using Talkies.Windows.Services;
using Xunit;

namespace Talkies.Windows.Tests.Services;

public sealed class SpeechRecognizerChainTests
{
    [Fact]
    public async Task Automatic_English_UsesPhonon2WhenInstalled()
    {
        var phonon = FakeRecognizer.Phonon2();
        var whisper = FakeRecognizer.Whisper();
        using var chain = new SpeechRecognizerChain(new ISpeechRecognizer[] { phonon, whisper });

        var result = await chain.RecognizeAsync(Request("en"));

        Assert.Equal("from phonon2", result.Text);
        Assert.Equal(1, phonon.Calls);
        Assert.Equal(0, whisper.Calls);
        Assert.Equal("Phonon-2", chain.LastRecognizerName);
        Assert.Equal(SpeechEnginePolicy.Phonon2Id, result.RecognizerId);
        Assert.Null(chain.LastFallbackReason);
    }

    [Fact]
    public async Task Automatic_AutoLanguage_UsesPhonon2()
    {
        var phonon = FakeRecognizer.Phonon2();
        var whisper = FakeRecognizer.Whisper();
        using var chain = new SpeechRecognizerChain(new ISpeechRecognizer[] { phonon, whisper });

        var result = await chain.RecognizeAsync(Request("auto"));

        Assert.Equal("from phonon2", result.Text);
        Assert.Equal(0, whisper.Calls);
    }

    [Fact]
    public async Task Phonon2NotInstalled_FallsBackToWhisperWithoutCallingPhonon2()
    {
        var phonon = FakeRecognizer.Phonon2(unavailableReason: "the Phonon-2 model has not been downloaded.");
        var whisper = FakeRecognizer.Whisper();
        using var chain = new SpeechRecognizerChain(new ISpeechRecognizer[] { phonon, whisper });

        var result = await chain.RecognizeAsync(Request("en"));

        Assert.Equal("from whisper", result.Text);
        Assert.Equal(0, phonon.Calls);
        Assert.Equal(1, whisper.Calls);
        Assert.Equal("Whisper", chain.LastRecognizerName);
        Assert.Equal(SpeechEnginePolicy.WhisperId, result.RecognizerId);
        Assert.Contains("not been downloaded", chain.LastFallbackReason);
    }

    [Fact]
    public async Task Phonon2Throws_FallsBackToWhisperAndReportsWhy()
    {
        var phonon = FakeRecognizer.Phonon2(failure: new InvalidOperationException("CrispASR could not load the Phonon-2 model."));
        var whisper = FakeRecognizer.Whisper();
        var progress = new RecordingProgress();
        using var chain = new SpeechRecognizerChain(new ISpeechRecognizer[] { phonon, whisper });

        var result = await chain.RecognizeAsync(Request("en"), progress);

        Assert.Equal("from whisper", result.Text);
        Assert.Equal(1, phonon.Calls);
        Assert.Equal(1, whisper.Calls);
        Assert.Contains("could not load", chain.LastFallbackReason);
        Assert.Contains(progress.Messages, message => message.Contains("using Whisper", StringComparison.Ordinal));
    }

    [Fact]
    public async Task Phonon2TimesOut_FallsBackToWhisper()
    {
        var phonon = FakeRecognizer.Phonon2(failure: new TimeoutException("Phonon-2 did not transcribe in time."));
        var whisper = FakeRecognizer.Whisper();
        using var chain = new SpeechRecognizerChain(new ISpeechRecognizer[] { phonon, whisper });

        var result = await chain.RecognizeAsync(Request("en"));

        Assert.Equal("from whisper", result.Text);
    }

    [Theory]
    [InlineData(SpeechEngine.Automatic, "es")]
    [InlineData(SpeechEngine.Automatic, "de")]
    [InlineData(SpeechEngine.Phonon2, "fr")]
    [InlineData(SpeechEngine.Phonon2, "ja")]
    public async Task NonEnglishLanguage_UsesWhisperOnly(SpeechEngine engine, string language)
    {
        var phonon = FakeRecognizer.Phonon2();
        var whisper = FakeRecognizer.Whisper();
        using var chain = new SpeechRecognizerChain(new ISpeechRecognizer[] { phonon, whisper }, engine);

        var result = await chain.RecognizeAsync(Request(language));

        Assert.Equal("from whisper", result.Text);
        Assert.Equal(0, phonon.Calls);
        Assert.Equal(0, phonon.AvailabilityChecks);
        Assert.Equal(language, whisper.LastRequest?.Language);
    }

    [Fact]
    public async Task ExplicitPhonon2_NonEnglish_ExplainsWhyWhisperWasUsed()
    {
        var phonon = FakeRecognizer.Phonon2();
        var whisper = FakeRecognizer.Whisper();
        using var chain = new SpeechRecognizerChain(new ISpeechRecognizer[] { phonon, whisper }, SpeechEngine.Phonon2);

        await chain.RecognizeAsync(Request("es"));

        Assert.Contains("English only", chain.LastFallbackReason);
    }

    [Fact]
    public async Task AutomaticNonEnglish_DoesNotReportAFallback()
    {
        using var chain = new SpeechRecognizerChain(new ISpeechRecognizer[] { FakeRecognizer.Phonon2(), FakeRecognizer.Whisper() });

        await chain.RecognizeAsync(Request("es"));

        Assert.Null(chain.LastFallbackReason);
    }

    [Theory]
    [InlineData("en")]
    [InlineData("auto")]
    [InlineData("es")]
    public async Task ExplicitWhisper_NeverTouchesPhonon2(string language)
    {
        var phonon = FakeRecognizer.Phonon2();
        var whisper = FakeRecognizer.Whisper();
        using var chain = new SpeechRecognizerChain(new ISpeechRecognizer[] { phonon, whisper }, SpeechEngine.Whisper);

        var result = await chain.RecognizeAsync(Request(language));

        Assert.Equal("from whisper", result.Text);
        Assert.Equal(0, phonon.Calls);
        Assert.Equal(0, phonon.AvailabilityChecks);
    }

    [Fact]
    public async Task EngineCanChangeBetweenRequests()
    {
        var phonon = FakeRecognizer.Phonon2();
        var whisper = FakeRecognizer.Whisper();
        using var chain = new SpeechRecognizerChain(new ISpeechRecognizer[] { phonon, whisper }, SpeechEngine.Whisper);

        await chain.RecognizeAsync(Request("en"));
        chain.Engine = SpeechEngine.Automatic;
        await chain.RecognizeAsync(Request("en"));

        Assert.Equal(1, whisper.Calls);
        Assert.Equal(1, phonon.Calls);
    }

    [Fact]
    public async Task WhisperFailure_IsReportedToTheCaller()
    {
        var phonon = FakeRecognizer.Phonon2(failure: new InvalidOperationException("phonon broke"));
        var whisper = FakeRecognizer.Whisper(failure: new System.IO.FileNotFoundException("Whisper model missing"));
        using var chain = new SpeechRecognizerChain(new ISpeechRecognizer[] { phonon, whisper });

        await Assert.ThrowsAsync<System.IO.FileNotFoundException>(() => chain.RecognizeAsync(Request("en")));
        Assert.Equal(1, whisper.Calls);
    }

    [Fact]
    public async Task Cancellation_IsNotTreatedAsAPhonon2Failure()
    {
        using var cancellation = new CancellationTokenSource();
        var phonon = FakeRecognizer.Phonon2(onRecognize: () =>
        {
            cancellation.Cancel();
            cancellation.Token.ThrowIfCancellationRequested();
        });
        var whisper = FakeRecognizer.Whisper();
        using var chain = new SpeechRecognizerChain(new ISpeechRecognizer[] { phonon, whisper });

        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => chain.RecognizeAsync(Request("en"), cancellationToken: cancellation.Token));
        Assert.Equal(0, whisper.Calls);
    }

    [Fact]
    public async Task ChainWithoutPhonon2_StillTranscribesWithWhisper()
    {
        var whisper = FakeRecognizer.Whisper();
        using var chain = new SpeechRecognizerChain(new ISpeechRecognizer[] { whisper });

        var result = await chain.RecognizeAsync(Request("en"));

        Assert.Equal("from whisper", result.Text);
    }

    [Fact]
    public void Chain_RequiresTheWhisperFallback()
    {
        Assert.Throws<ArgumentException>(() => new SpeechRecognizerChain(new ISpeechRecognizer[] { FakeRecognizer.Phonon2() }));
    }

    [Fact]
    public async Task TranscribeAsync_ForwardsAllRequestFieldsToTheRecognizer()
    {
        var whisper = FakeRecognizer.Whisper();
        var options = new DecodingOptions { Prompt = "Talkies" };
        using var chain = new SpeechRecognizerChain(new ISpeechRecognizer[] { whisper }, SpeechEngine.Whisper);

        await chain.TranscribeAsync("clip.wav", "base", "de", vadEnabled: true, filterEnabled: false, options);

        Assert.Equal(new SpeechRecognitionRequest("clip.wav", "base", "de", true, false, options), whisper.LastRequest);
    }

    [Fact]
    public void Dispose_DisposesEveryRecognizer()
    {
        var phonon = FakeRecognizer.Phonon2();
        var whisper = FakeRecognizer.Whisper();
        var chain = new SpeechRecognizerChain(new ISpeechRecognizer[] { phonon, whisper });

        chain.Dispose();

        Assert.True(phonon.Disposed);
        Assert.True(whisper.Disposed);
    }

    private static SpeechRecognitionRequest Request(string language) =>
        new("recording.wav", "tiny", language, VadEnabled: true, FilterEnabled: true);

    private sealed class FakeRecognizer : ISpeechRecognizer
    {
        private readonly string? _unavailableReason;
        private readonly Exception? _failure;
        private readonly Action? _onRecognize;

        private FakeRecognizer(string id, string displayName, string? unavailableReason, Exception? failure, Action? onRecognize)
        {
            Id = id;
            DisplayName = displayName;
            _unavailableReason = unavailableReason;
            _failure = failure;
            _onRecognize = onRecognize;
        }

        public static FakeRecognizer Phonon2(string? unavailableReason = null, Exception? failure = null, Action? onRecognize = null) =>
            new(SpeechEnginePolicy.Phonon2Id, "Phonon-2", unavailableReason, failure, onRecognize);

        public static FakeRecognizer Whisper(Exception? failure = null) =>
            new(SpeechEnginePolicy.WhisperId, "Whisper", null, failure, null);

        public string Id { get; }
        public string DisplayName { get; }
        public int Calls { get; private set; }
        public int AvailabilityChecks { get; private set; }
        public SpeechRecognitionRequest? LastRequest { get; private set; }
        public bool Disposed { get; private set; }

        public string? GetUnavailableReason()
        {
            AvailabilityChecks++;
            return _unavailableReason;
        }

        public Task<TranscriptionResult> RecognizeAsync(SpeechRecognitionRequest request, IProgress<TranscriptionProgress>? progress = null, CancellationToken cancellationToken = default)
        {
            Calls++;
            LastRequest = request;
            _onRecognize?.Invoke();
            if (_failure is not null) return Task.FromException<TranscriptionResult>(_failure);
            return Task.FromResult(new TranscriptionResult
            {
                Text = $"from {Id}",
                Segments = new List<TranscriptSegment> { new() { Text = $"from {Id}", Start = 0, End = 1 } },
            });
        }

        public void Dispose() => Disposed = true;
    }

    private sealed class RecordingProgress : IProgress<TranscriptionProgress>
    {
        public List<string> Messages { get; } = new();
        public void Report(TranscriptionProgress value) => Messages.Add(value.Message ?? string.Empty);
    }
}
