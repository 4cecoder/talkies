using System;
using System.IO;
using Talkies.Windows.Services;
using Xunit;

namespace Talkies.Windows.Tests.Services;

public sealed class CrispAsrWorkerProtocolTests
{
    [Fact]
    public void Hello_RoundTrips()
    {
        using var stream = new MemoryStream();
        CrispAsrWorkerProtocol.WriteHello(new BinaryWriter(stream), ok: true, "CrispASR 0.8.43 (parakeet, CPU)");
        stream.Position = 0;

        var (ok, message) = CrispAsrWorkerProtocol.ReadHello(new BinaryReader(stream));

        Assert.True(ok);
        Assert.Equal("CrispASR 0.8.43 (parakeet, CPU)", message);
    }

    [Fact]
    public void Hello_RejectsAnotherProtocol()
    {
        using var stream = new MemoryStream(new byte[] { 1, 2, 3, 4, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 });

        Assert.Throws<InvalidDataException>(() => CrispAsrWorkerProtocol.ReadHello(new BinaryReader(stream)));
    }

    [Fact]
    public void TranscribeRequest_RoundTripsSamplesExactly()
    {
        var samples = new[] { 0f, 0.5f, -1f, 1f, float.Epsilon, -0.25f };
        using var stream = new MemoryStream();
        CrispAsrWorkerProtocol.WriteTranscribeRequest(new BinaryWriter(stream), "en", samples);
        stream.Position = 0;

        var request = CrispAsrWorkerProtocol.ReadRequest(new BinaryReader(stream));

        Assert.NotNull(request);
        Assert.Equal("en", request!.Value.Language);
        Assert.Equal(samples, request.Value.Samples);
    }

    [Fact]
    public void ReadRequest_ReturnsNullForShutdownAndClosedPipe()
    {
        using var shutdown = new MemoryStream();
        CrispAsrWorkerProtocol.WriteShutdown(new BinaryWriter(shutdown));
        shutdown.Position = 0;

        Assert.Null(CrispAsrWorkerProtocol.ReadRequest(new BinaryReader(shutdown)));
        Assert.Null(CrispAsrWorkerProtocol.ReadRequest(new BinaryReader(new MemoryStream())));
    }

    [Fact]
    public void ReadRequest_RejectsOversizedSampleCounts()
    {
        using var stream = new MemoryStream();
        var writer = new BinaryWriter(stream);
        writer.Write(1); // transcribe
        writer.Write(2); // language length
        writer.Write("en"u8.ToArray());
        writer.Write(CrispAsrWorkerProtocol.MaxSamples + 1);
        stream.Position = 0;

        Assert.Throws<InvalidDataException>(() => CrispAsrWorkerProtocol.ReadRequest(new BinaryReader(stream)));
    }

    [Fact]
    public void Response_RoundTripsUnicodeSegments()
    {
        var segments = new[]
        {
            new CrispAsrSegment("Hello, naïve café.", 0, 150),
            new CrispAsrSegment("Second sentence", 150, 420),
        };
        using var stream = new MemoryStream();
        CrispAsrWorkerProtocol.WriteResult(new BinaryWriter(stream), segments);
        stream.Position = 0;

        var read = CrispAsrWorkerProtocol.ReadResponse(new BinaryReader(stream));

        Assert.Equal(segments, read);
    }

    [Fact]
    public void Response_SurfacesWorkerErrors()
    {
        using var stream = new MemoryStream();
        CrispAsrWorkerProtocol.WriteError(new BinaryWriter(stream), "CrispASR returned no Phonon-2 result.");
        stream.Position = 0;

        var error = Assert.Throws<InvalidOperationException>(() => CrispAsrWorkerProtocol.ReadResponse(new BinaryReader(stream)));
        Assert.Equal("CrispASR returned no Phonon-2 result.", error.Message);
    }

    [Fact]
    public void Response_TruncatedStreamThrows()
    {
        using var stream = new MemoryStream();
        CrispAsrWorkerProtocol.WriteResult(new BinaryWriter(stream), new[] { new CrispAsrSegment("text", 0, 10) });
        var truncated = new MemoryStream(stream.ToArray()[..^4]);

        Assert.Throws<EndOfStreamException>(() => CrispAsrWorkerProtocol.ReadResponse(new BinaryReader(truncated)));
    }

    [Fact]
    public void WorkerInvocation_RequiresTheExactFlag()
    {
        Assert.True(CrispAsrWorker.IsWorkerInvocation(new[] { "--crispasr-worker", "1", "2", "m", "4" }));
        Assert.False(CrispAsrWorker.IsWorkerInvocation(Array.Empty<string>()));
        Assert.False(CrispAsrWorker.IsWorkerInvocation(new[] { "--CRISPASR-WORKER" }));
        Assert.False(CrispAsrWorker.IsWorkerInvocation(new[] { "recording.wav" }));
    }
}
