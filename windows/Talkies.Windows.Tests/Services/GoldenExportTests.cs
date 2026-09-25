using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using Talkies.Windows.Models;
using Talkies.Windows.Services;
using Xunit;

namespace Talkies.Windows.Tests.Services;

public class GoldenExportTests
{
    [Fact]
    public void TranscriptExportsMatchSharedCrossPlatformGoldenFixture()
    {
        var fixturePath = Path.Combine(AppContext.BaseDirectory, "Fixtures", "transcript-export-golden.json");
        var fixture = JsonSerializer.Deserialize<ExportGoldenFixture>(File.ReadAllText(fixturePath), new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        })!;

        Assert.Equal(fixture.Txt, NormalizeLineEndings(TranscriptExporter.ExportToTxt(fixture.Segments)));
        Assert.Equal(fixture.Vtt, NormalizeLineEndings(TranscriptExporter.ExportToVtt(fixture.Segments)));
        Assert.Equal(fixture.Srt, NormalizeLineEndings(TranscriptExporter.ExportToSrt(fixture.Segments)));
    }

    private static string NormalizeLineEndings(string value) => value.Replace("\r\n", "\n");

    private sealed class ExportGoldenFixture
    {
        public ExportGoldenFixture() { }

        public List<TranscriptSegment> Segments { get; init; } = [];
        public string Txt { get; init; } = string.Empty;
        public string Vtt { get; init; } = string.Empty;
        public string Srt { get; init; } = string.Empty;
    }
}
