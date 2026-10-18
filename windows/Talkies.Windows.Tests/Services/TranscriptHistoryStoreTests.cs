using System;
using System.IO;
using System.Linq;
using Microsoft.Data.Sqlite;
using Talkies.Windows.Models;
using Talkies.Windows.Services;
using Xunit;

namespace Talkies.Windows.Tests.Services;

public sealed class TranscriptHistoryStoreTests : IDisposable
{
    private static readonly DateTimeOffset BaseTime = new(2026, 10, 1, 12, 0, 0, TimeSpan.Zero);
    private readonly string _directory = Path.Combine(Path.GetTempPath(), "talkies-history-" + Guid.NewGuid().ToString("N"));

    private string DatabasePath => Path.Combine(_directory, TranscriptHistoryStore.FileName);

    public void Dispose()
    {
        if (Directory.Exists(_directory)) Directory.Delete(_directory, recursive: true);
    }

    [Fact]
    public void NewDatabase_IsMigratedToSharedSchemaInWalMode()
    {
        var store = new TranscriptHistoryStore(DatabasePath);

        Assert.True(File.Exists(DatabasePath));
        Assert.Equal(TranscriptHistoryStore.SchemaVersion, store.GetSchemaVersion());
        Assert.Equal(1, TranscriptHistoryStore.SchemaVersion);

        using var connection = OpenRaw();
        Assert.Equal("wal", Scalar(connection, "PRAGMA journal_mode;"));
        var columns = Column(connection, "SELECT name FROM pragma_table_info('transcripts') ORDER BY cid;");
        Assert.Equal(new[] { "id", "uuid", "created_at", "text", "raw_text", "duration_ms", "runtime", "language" }, columns);
        var notNull = Column(connection, "SELECT name FROM pragma_table_info('transcripts') WHERE \"notnull\" = 1 ORDER BY cid;");
        Assert.Equal(new[] { "uuid", "created_at", "text" }, notNull);
        Assert.Equal("transcripts_created_at", Scalar(connection, "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'transcripts' AND name = 'transcripts_created_at';"));
        Assert.Equal(1L, Convert.ToInt64(Scalar(connection, "SELECT COUNT(*) FROM pragma_index_list('transcripts') WHERE \"unique\" = 1 AND origin = 'u';")));
    }

    [Fact]
    public void Reopen_KeepsDataAndDoesNotRerunMigrations()
    {
        new TranscriptHistoryStore(DatabasePath).Add(new NewTranscript(BaseTime, "first"));

        var reopened = new TranscriptHistoryStore(DatabasePath);

        Assert.Equal(1, reopened.GetSchemaVersion());
        Assert.Equal("first", Assert.Single(reopened.GetPage(null, 0, 10)).Text);
    }

    [Fact]
    public void NewerSchemaVersion_IsRejectedWithoutChangingTheFile()
    {
        Directory.CreateDirectory(_directory);
        using (var connection = OpenRaw())
        {
            Execute(connection, "PRAGMA user_version = 2;");
        }

        var error = Assert.Throws<InvalidOperationException>(() => new TranscriptHistoryStore(DatabasePath));
        Assert.Contains("newer version", error.Message, StringComparison.Ordinal);
        using var check = OpenRaw();
        Assert.Equal(2L, Convert.ToInt64(Scalar(check, "PRAGMA user_version;")));
    }

    [Fact]
    public void Add_StoresAllFieldsWithLowercaseUuidV4()
    {
        var store = new TranscriptHistoryStore(DatabasePath);

        var added = store.Add(new NewTranscript(BaseTime, "Hello, world.", "hello world", 2_500, TranscriptRuntime.Phonon, "en"));

        var saved = Assert.Single(store.GetPage(null, 0, 10));
        Assert.Equal(added, saved);
        Assert.Equal("Hello, world.", saved.Text);
        Assert.Equal("hello world", saved.RawText);
        Assert.Equal(2_500, saved.DurationMs);
        Assert.Equal("phonon", saved.Runtime);
        Assert.Equal("en", saved.Language);
        Assert.Equal(BaseTime, saved.CreatedAt);
        Assert.Matches("^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$", saved.Uuid);

        using var connection = OpenRaw();
        Assert.Equal(BaseTime.ToUnixTimeMilliseconds(), Convert.ToInt64(Scalar(connection, "SELECT created_at FROM transcripts;")));
    }

    [Fact]
    public void Add_StoresNullRawTextWhenIdenticalAndNullOptionalFields()
    {
        var store = new TranscriptHistoryStore(DatabasePath);

        store.Add(new NewTranscript(BaseTime, "same text", "same text"));

        var saved = Assert.Single(store.GetPage(null, 0, 10));
        Assert.Null(saved.RawText);
        Assert.Null(saved.DurationMs);
        Assert.Null(saved.Runtime);
        Assert.Null(saved.Language);
    }

    [Fact]
    public void Add_GivesEachTranscriptADistinctUuid()
    {
        var store = new TranscriptHistoryStore(DatabasePath);

        var uuids = Enumerable.Range(0, 20).Select(i => store.Add(new NewTranscript(BaseTime, $"t{i}")).Uuid).ToList();

        Assert.Equal(uuids.Count, uuids.Distinct(StringComparer.Ordinal).Count());
    }

    [Fact]
    public void GetPage_ReturnsNewestFirstAndPages()
    {
        var store = new TranscriptHistoryStore(DatabasePath);
        store.Add(new NewTranscript(BaseTime.AddMinutes(1), "middle"));
        store.Add(new NewTranscript(BaseTime.AddMinutes(2), "newest"));
        store.Add(new NewTranscript(BaseTime, "oldest"));

        Assert.Equal(new[] { "newest", "middle", "oldest" }, store.GetPage(null, 0, 10).Select(r => r.Text));
        Assert.Equal(new[] { "newest", "middle" }, store.GetPage(null, 0, 2).Select(r => r.Text));
        Assert.Equal(new[] { "oldest" }, store.GetPage(null, 2, 2).Select(r => r.Text));
        Assert.Empty(store.GetPage(null, 4, 2));
        Assert.Equal(3, store.Count());
    }

    [Fact]
    public void Search_MatchesSubstringCaseInsensitivelyAndTreatsWildcardsLiterally()
    {
        var store = new TranscriptHistoryStore(DatabasePath);
        store.Add(new NewTranscript(BaseTime, "Meeting notes for Monday"));
        store.Add(new NewTranscript(BaseTime.AddMinutes(1), "Grocery list", RawText: "meeting raw only"));
        store.Add(new NewTranscript(BaseTime.AddMinutes(2), "100% done"));
        store.Add(new NewTranscript(BaseTime.AddMinutes(3), "1000 done"));
        store.Add(new NewTranscript(BaseTime.AddMinutes(4), "snake_case name"));
        store.Add(new NewTranscript(BaseTime.AddMinutes(5), "snakeXcase name"));
        store.Add(new NewTranscript(BaseTime.AddMinutes(6), "Robert'); DROP TABLE transcripts;--"));

        Assert.Equal(new[] { "Meeting notes for Monday" }, store.GetPage("meeting", 0, 10).Select(r => r.Text));
        Assert.Equal(new[] { "100% done" }, store.GetPage("0%", 0, 10).Select(r => r.Text));
        Assert.Equal(new[] { "snake_case name" }, store.GetPage("e_c", 0, 10).Select(r => r.Text));
        Assert.Single(store.GetPage("DROP TABLE", 0, 10));
        Assert.Equal(1, store.Count("monday"));
        Assert.Equal(7, store.Count("  "));
        Assert.Equal(7, store.Count());
    }

    [Fact]
    public void Delete_RemovesOnlyThatTranscript()
    {
        var store = new TranscriptHistoryStore(DatabasePath);
        var keep = store.Add(new NewTranscript(BaseTime, "keep"));
        var remove = store.Add(new NewTranscript(BaseTime.AddMinutes(1), "remove"));
        var changes = 0;
        store.Changed += (_, _) => changes++;

        Assert.True(store.Delete(remove.Id));
        Assert.False(store.Delete(remove.Id));

        Assert.Equal(keep, Assert.Single(store.GetPage(null, 0, 10)));
        Assert.Equal(1, changes);
    }

    [Fact]
    public void Clear_DeletesEverythingAndLeavesAWorkingEmptyStore()
    {
        var store = new TranscriptHistoryStore(DatabasePath);
        for (var i = 0; i < 50; i++) store.Add(new NewTranscript(BaseTime.AddSeconds(i), new string('x', 1_000) + i));
        var changes = 0;
        store.Changed += (_, _) => changes++;

        store.Clear();

        Assert.Equal(0, store.Count());
        Assert.Empty(store.GetPage(null, 0, 10));
        Assert.Equal(1, changes);
        Assert.Equal(1, store.GetSchemaVersion());
        store.Add(new NewTranscript(BaseTime, "after clear"));
        Assert.Equal(1, store.Count());
    }

    [Fact]
    public void RuntimeIds_MapToSharedColumnValues()
    {
        Assert.Equal("phonon", TranscriptRuntime.FromRecognizerId(SpeechEnginePolicy.Phonon2Id));
        Assert.Equal("whisper", TranscriptRuntime.FromRecognizerId(SpeechEnginePolicy.WhisperId));
        Assert.Null(TranscriptRuntime.FromRecognizerId(null));
        Assert.Null(TranscriptRuntime.FromRecognizerId("other"));
    }

    private SqliteConnection OpenRaw()
    {
        var connection = new SqliteConnection(new SqliteConnectionStringBuilder { DataSource = DatabasePath, Pooling = false }.ToString());
        connection.Open();
        return connection;
    }

    private static object? Scalar(SqliteConnection connection, string sql)
    {
        using var command = connection.CreateCommand();
        command.CommandText = sql;
        return command.ExecuteScalar();
    }

    private static void Execute(SqliteConnection connection, string sql)
    {
        using var command = connection.CreateCommand();
        command.CommandText = sql;
        command.ExecuteNonQuery();
    }

    private static string[] Column(SqliteConnection connection, string sql)
    {
        using var command = connection.CreateCommand();
        command.CommandText = sql;
        using var reader = command.ExecuteReader();
        var values = new System.Collections.Generic.List<string>();
        while (reader.Read()) values.Add(reader.GetString(0));
        return values.ToArray();
    }
}
