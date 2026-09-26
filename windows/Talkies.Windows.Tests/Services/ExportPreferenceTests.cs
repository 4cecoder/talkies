using System;
using System.Collections.Generic;
using Talkies.Windows.Models;
using Talkies.Windows.Services;
using Xunit;

namespace Talkies.Windows.Tests.Services
{
    public class ExportPreferenceTests
    {
        [Fact]
        public void FilenameTemplate_ExpandsSupportedTokensAndAddsExtension()
        {
            var name = TranscriptExporter.BuildFileName("{date}_{time}_{duration}_{model}", "txt",
                new DateTime(2026, 9, 25, 14, 5, 6), 65, "small/model");

            Assert.Equal("2026-09-25_14-05-06_00-01-05_small_model.txt", name);
        }

        [Fact]
        public void FilenameTemplate_UsesSafeFallbackForBlankTemplate()
        {
            Assert.Equal("talkies.vtt", TranscriptExporter.BuildFileName("   ", ".vtt", DateTime.UnixEpoch, 0, "base"));
        }

        [Fact]
        public void TxtExport_CanOmitTimestamps()
        {
            var segments = new List<TranscriptSegment>
            {
                new() { Timestamp = "00:00:01.000", Text = "First" },
                new() { Timestamp = "00:00:02.000", Text = "Second" }
            };

            Assert.Equal("First" + Environment.NewLine + "Second" + Environment.NewLine,
                TranscriptExporter.ExportToTxt(segments, includeTimestamps: false));
        }

        [Fact]
        public void ExportPreferencesHaveUsefulOfflineDefaults()
        {
            var settings = new AppSettings().Export;

            Assert.Equal("VTT", settings.DefaultFormat);
            Assert.False(settings.AutoExport);
            Assert.True(settings.IncludeTimestamps);
            Assert.NotEmpty(settings.ExportDirectory);
            Assert.Equal("{date}_{time}", settings.FilenameTemplate);
        }

        [Fact]
        public void ExportPreferencesSurviveSettingsSerialization()
        {
            var original = new AppSettings();
            original.Export.DefaultFormat = "TXT";
            original.Export.ExportDirectory = @"C:\Talkies Exports";
            original.Export.FilenameTemplate = "{model}_{date}";
            original.Export.IncludeTimestamps = false;
            original.Export.AutoExport = true;
            original.Export.RecentExports.Add(@"C:\Talkies Exports\sample.txt");

            var restored = Newtonsoft.Json.JsonConvert.DeserializeObject<AppSettings>(
                Newtonsoft.Json.JsonConvert.SerializeObject(original))!;

            Assert.Equal(original.Export.DefaultFormat, restored.Export.DefaultFormat);
            Assert.Equal(original.Export.ExportDirectory, restored.Export.ExportDirectory);
            Assert.Equal(original.Export.FilenameTemplate, restored.Export.FilenameTemplate);
            Assert.Equal(original.Export.IncludeTimestamps, restored.Export.IncludeTimestamps);
            Assert.Equal(original.Export.AutoExport, restored.Export.AutoExport);
            Assert.Equal(original.Export.RecentExports, restored.Export.RecentExports);
        }
    }
}
