using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using Microsoft.Data.Sqlite;
using Talkies.Windows.Models;

namespace Talkies.Windows.Services
{
    /// <summary>Persistent, on-device transcript history.</summary>
    public interface ITranscriptHistoryStore
    {
        /// <summary>Raised after an insert, delete, or clear. May fire on any thread.</summary>
        event EventHandler? Changed;

        TranscriptRecord Add(NewTranscript transcript);

        /// <summary>Returns saved transcripts newest first, optionally filtered by a substring of the final text.</summary>
        IReadOnlyList<TranscriptRecord> GetPage(string? search, int offset, int limit);

        int Count(string? search = null);

        bool Delete(long id);

        /// <summary>Deletes every transcript and compacts the database file.</summary>
        void Clear();
    }

    /// <summary>
    /// SQLite transcript history at <c>%LOCALAPPDATA%\Talkies\history.sqlite</c>. The schema is shared
    /// with the other Talkies clients; migrations are keyed on <c>PRAGMA user_version</c>.
    /// Transcript text is never logged.
    /// </summary>
    public sealed class TranscriptHistoryStore : ITranscriptHistoryStore
    {
        public const int SchemaVersion = 1;
        public const string FileName = "history.sqlite";

        // Index i migrates the database from user_version i to i + 1.
        private static readonly string[] Migrations =
        {
            """
            CREATE TABLE IF NOT EXISTS transcripts (
              id INTEGER PRIMARY KEY,
              uuid TEXT NOT NULL UNIQUE,
              created_at INTEGER NOT NULL,
              text TEXT NOT NULL,
              raw_text TEXT,
              duration_ms INTEGER,
              runtime TEXT,
              language TEXT
            );
            CREATE INDEX IF NOT EXISTS transcripts_created_at ON transcripts(created_at DESC);
            """,
        };

        private const string Columns = "id, uuid, created_at, text, raw_text, duration_ms, runtime, language";

        private readonly string _connectionString;
        private readonly object _sync = new();

        public event EventHandler? Changed;

        public TranscriptHistoryStore(string? path = null)
        {
            Path = path ?? DefaultPath;
            Directory.CreateDirectory(System.IO.Path.GetDirectoryName(System.IO.Path.GetFullPath(Path))!);
            _connectionString = new SqliteConnectionStringBuilder
            {
                DataSource = Path,
                Mode = SqliteOpenMode.ReadWriteCreate,
                // Without pooling, the file is released after each operation (clean uninstall, temp-dir tests).
                Pooling = false,
            }.ToString();

            lock (_sync)
            {
                using var connection = Open();
                Migrate(connection);
            }
        }

        public static string DefaultPath => System.IO.Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Talkies", FileName);

        public string Path { get; }

        public TranscriptRecord Add(NewTranscript transcript)
        {
            ArgumentNullException.ThrowIfNull(transcript);
            ArgumentNullException.ThrowIfNull(transcript.Text);
            var uuid = Guid.NewGuid().ToString("D"); // Guid.NewGuid is a random (version 4) UUID; "D" is lowercase.
            var createdAtMs = transcript.CreatedAt.ToUnixTimeMilliseconds();
            var rawText = string.Equals(transcript.RawText, transcript.Text, StringComparison.Ordinal) ? null : transcript.RawText;

            long id;
            lock (_sync)
            {
                using var connection = Open();
                using var command = connection.CreateCommand();
                command.CommandText = """
                    INSERT INTO transcripts (uuid, created_at, text, raw_text, duration_ms, runtime, language)
                    VALUES ($uuid, $created_at, $text, $raw_text, $duration_ms, $runtime, $language)
                    RETURNING id;
                    """;
                command.Parameters.AddWithValue("$uuid", uuid);
                command.Parameters.AddWithValue("$created_at", createdAtMs);
                command.Parameters.AddWithValue("$text", transcript.Text);
                command.Parameters.AddWithValue("$raw_text", (object?)rawText ?? DBNull.Value);
                command.Parameters.AddWithValue("$duration_ms", (object?)transcript.DurationMs ?? DBNull.Value);
                command.Parameters.AddWithValue("$runtime", (object?)transcript.Runtime ?? DBNull.Value);
                command.Parameters.AddWithValue("$language", (object?)transcript.Language ?? DBNull.Value);
                id = (long)command.ExecuteScalar()!;
            }

            Changed?.Invoke(this, EventArgs.Empty);
            return new TranscriptRecord(
                id,
                uuid,
                DateTimeOffset.FromUnixTimeMilliseconds(createdAtMs),
                transcript.Text,
                rawText,
                transcript.DurationMs,
                transcript.Runtime,
                transcript.Language);
        }

        public IReadOnlyList<TranscriptRecord> GetPage(string? search, int offset, int limit)
        {
            if (offset < 0) throw new ArgumentOutOfRangeException(nameof(offset));
            if (limit <= 0) throw new ArgumentOutOfRangeException(nameof(limit));

            lock (_sync)
            {
                using var connection = Open();
                using var command = connection.CreateCommand();
                command.CommandText = $"SELECT {Columns} FROM transcripts{WhereClause(command, search)} " +
                    "ORDER BY created_at DESC, id DESC LIMIT $limit OFFSET $offset;";
                command.Parameters.AddWithValue("$limit", limit);
                command.Parameters.AddWithValue("$offset", offset);

                var records = new List<TranscriptRecord>();
                using var reader = command.ExecuteReader();
                while (reader.Read())
                {
                    records.Add(new TranscriptRecord(
                        reader.GetInt64(0),
                        reader.GetString(1),
                        DateTimeOffset.FromUnixTimeMilliseconds(reader.GetInt64(2)),
                        reader.GetString(3),
                        reader.IsDBNull(4) ? null : reader.GetString(4),
                        reader.IsDBNull(5) ? null : reader.GetInt64(5),
                        reader.IsDBNull(6) ? null : reader.GetString(6),
                        reader.IsDBNull(7) ? null : reader.GetString(7)));
                }
                return records;
            }
        }

        public int Count(string? search = null)
        {
            lock (_sync)
            {
                using var connection = Open();
                using var command = connection.CreateCommand();
                command.CommandText = $"SELECT COUNT(*) FROM transcripts{WhereClause(command, search)};";
                return Convert.ToInt32(command.ExecuteScalar());
            }
        }

        public bool Delete(long id)
        {
            int deleted;
            lock (_sync)
            {
                using var connection = Open();
                using var command = connection.CreateCommand();
                command.CommandText = "DELETE FROM transcripts WHERE id = $id;";
                command.Parameters.AddWithValue("$id", id);
                deleted = command.ExecuteNonQuery();
                if (deleted > 0) Checkpoint(connection);
            }

            if (deleted > 0) Changed?.Invoke(this, EventArgs.Empty);
            return deleted > 0;
        }

        public void Clear()
        {
            lock (_sync)
            {
                using var connection = Open();
                using (var delete = connection.CreateCommand())
                {
                    delete.CommandText = "DELETE FROM transcripts;";
                    delete.ExecuteNonQuery();
                }
                using (var vacuum = connection.CreateCommand())
                {
                    vacuum.CommandText = "VACUUM;";
                    vacuum.ExecuteNonQuery();
                }
                Checkpoint(connection);
            }
            Logger.Info("Transcript history cleared");
            Changed?.Invoke(this, EventArgs.Empty);
        }

        /// <summary>Current <c>PRAGMA user_version</c> of the database file.</summary>
        public int GetSchemaVersion()
        {
            lock (_sync)
            {
                using var connection = Open();
                return ReadUserVersion(connection);
            }
        }

        /// <summary>
        /// Builds a parameterized LIKE filter. <c>%</c>, <c>_</c>, and the escape character in the
        /// search text match literally.
        /// </summary>
        private static string WhereClause(SqliteCommand command, string? search)
        {
            if (string.IsNullOrWhiteSpace(search)) return string.Empty;
            command.Parameters.AddWithValue("$pattern", "%" + EscapeLike(search.Trim()) + "%");
            return @" WHERE text LIKE $pattern ESCAPE '\'";
        }

        internal static string EscapeLike(string value)
        {
            var builder = new StringBuilder(value.Length);
            foreach (var c in value)
            {
                if (c is '\\' or '%' or '_') builder.Append('\\');
                builder.Append(c);
            }
            return builder.ToString();
        }

        private SqliteConnection Open()
        {
            var connection = new SqliteConnection(_connectionString);
            try
            {
                connection.Open();
                using var pragma = connection.CreateCommand();
                // WAL persists in the file; secure_delete zeroes deleted transcript text on disk.
                pragma.CommandText = "PRAGMA journal_mode = WAL; PRAGMA secure_delete = ON; PRAGMA busy_timeout = 5000;";
                pragma.ExecuteNonQuery();
                return connection;
            }
            catch
            {
                connection.Dispose();
                throw;
            }
        }

        private static void Migrate(SqliteConnection connection)
        {
            var version = ReadUserVersion(connection);
            if (version > SchemaVersion)
                throw new InvalidOperationException(
                    $"Transcript history was created by a newer version of Talkies (schema {version}; this version supports {SchemaVersion}). Update Talkies to use it.");

            while (version < SchemaVersion)
            {
                using var transaction = connection.BeginTransaction();
                using (var command = connection.CreateCommand())
                {
                    command.Transaction = transaction;
                    command.CommandText = Migrations[version];
                    command.ExecuteNonQuery();
                }
                version++;
                using (var command = connection.CreateCommand())
                {
                    command.Transaction = transaction;
                    // PRAGMA arguments cannot be parameters; version is an int from this class.
                    command.CommandText = $"PRAGMA user_version = {version};";
                    command.ExecuteNonQuery();
                }
                transaction.Commit();
                Logger.Info($"Transcript history schema migrated to version {version}");
            }
        }

        private static int ReadUserVersion(SqliteConnection connection)
        {
            using var command = connection.CreateCommand();
            command.CommandText = "PRAGMA user_version;";
            return Convert.ToInt32(command.ExecuteScalar());
        }

        /// <summary>Moves deleted pages out of the write-ahead log so removed text does not linger in it.</summary>
        private static void Checkpoint(SqliteConnection connection)
        {
            using var command = connection.CreateCommand();
            command.CommandText = "PRAGMA wal_checkpoint(TRUNCATE);";
            command.ExecuteNonQuery();
        }
    }
}
