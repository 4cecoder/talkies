-- Transcript history, schema version 1 (PRAGMA user_version = 1).
-- Location: $XDG_DATA_HOME/talkies/history.sqlite (~/.local/share/talkies/).
-- Shared by every Talkies client so history can sync between devices: keep
-- column names, types and meanings identical on all platforms.
CREATE TABLE IF NOT EXISTS transcripts (
  id INTEGER PRIMARY KEY,
  uuid TEXT NOT NULL UNIQUE,     -- random lowercase UUIDv4, stable across devices
  created_at INTEGER NOT NULL,   -- Unix epoch milliseconds, UTC
  text TEXT NOT NULL,            -- final text that was inserted (after cleanup)
  raw_text TEXT,                 -- recognizer output before cleanup; NULL when identical
  duration_ms INTEGER,           -- audio length
  runtime TEXT,                  -- 'phonon' | 'whisper'
  language TEXT                  -- NULL when unknown
);
CREATE INDEX IF NOT EXISTS transcripts_created_at ON transcripts(created_at DESC);
