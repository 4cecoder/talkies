-- YAP Session Management Schema
-- Location: ~/.local/share/talkies/yap_sessions.db

-- Main sessions table
CREATE TABLE IF NOT EXISTS sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at INTEGER NOT NULL,           -- Unix timestamp
    updated_at INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'active', -- active, completed, abandoned

    -- Session data
    initial_context TEXT,                  -- Optional pasted context
    yapping TEXT NOT NULL,                 -- Original voice transcription
    final_message TEXT,                    -- Accepted final version

    -- Metadata
    yapping_duration_ms INTEGER,           -- Recording duration
    yapping_word_count INTEGER,
    refinement_count INTEGER DEFAULT 0,

    -- Model info
    llm_model TEXT,
    ollama_url TEXT
);

-- Revision history per session
CREATE TABLE IF NOT EXISTS revisions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    revision_number INTEGER NOT NULL,      -- 1, 2, 3...

    text TEXT NOT NULL,
    char_count INTEGER NOT NULL,
    word_count INTEGER,

    -- What triggered this revision
    trigger_type TEXT,                     -- initial, refine_request, auto
    trigger_context TEXT,                  -- Additional user instructions

    FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
);

-- LLM conversation history per session
CREATE TABLE IF NOT EXISTS conversation_messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id INTEGER NOT NULL,
    message_number INTEGER NOT NULL,
    created_at INTEGER NOT NULL,

    role TEXT NOT NULL,                    -- system, user, assistant
    content TEXT NOT NULL,

    FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
);

-- Session statistics and analytics
CREATE TABLE IF NOT EXISTS session_stats (
    session_id INTEGER PRIMARY KEY,

    -- Compression metrics
    original_chars INTEGER,
    final_chars INTEGER,
    compression_ratio REAL,                -- final/original

    -- Time metrics
    total_duration_ms INTEGER,             -- From creation to completion
    llm_total_time_ms INTEGER,             -- Total LLM inference time

    -- Quality metrics
    revision_count INTEGER,
    accepted_revision INTEGER,             -- Which revision was accepted

    FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_sessions_status ON sessions(status);
CREATE INDEX IF NOT EXISTS idx_sessions_created ON sessions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_revisions_session ON revisions(session_id, revision_number);

-- Full-text search for past yapping sessions
CREATE VIRTUAL TABLE IF NOT EXISTS sessions_fts USING fts5(
    yapping,
    final_message,
    initial_context,
    content=sessions,
    content_rowid=id
);

-- Triggers to keep FTS index updated
CREATE TRIGGER IF NOT EXISTS sessions_fts_insert AFTER INSERT ON sessions BEGIN
    INSERT INTO sessions_fts(rowid, yapping, final_message, initial_context)
    VALUES (new.id, new.yapping, new.final_message, new.initial_context);
END;

CREATE TRIGGER IF NOT EXISTS sessions_fts_update AFTER UPDATE ON sessions BEGIN
    UPDATE sessions_fts
    SET yapping = new.yapping,
        final_message = new.final_message,
        initial_context = new.initial_context
    WHERE rowid = new.id;
END;

CREATE TRIGGER IF NOT EXISTS sessions_fts_delete AFTER DELETE ON sessions BEGIN
    DELETE FROM sessions_fts WHERE rowid = old.id;
END;

-- Views for common queries

-- Active session (should only be 0 or 1)
CREATE VIEW IF NOT EXISTS active_session AS
SELECT * FROM sessions WHERE status = 'active' LIMIT 1;

-- Recent sessions with stats
CREATE VIEW IF NOT EXISTS recent_sessions AS
SELECT
    s.*,
    st.compression_ratio,
    st.revision_count,
    COUNT(r.id) as actual_revision_count
FROM sessions s
LEFT JOIN session_stats st ON s.id = st.session_id
LEFT JOIN revisions r ON s.id = r.session_id
WHERE s.status != 'abandoned'
GROUP BY s.id
ORDER BY s.created_at DESC
LIMIT 50;
