const std = @import("std");
const c = @cImport({
    @cInclude("sqlite3.h");
});
const utils = @import("utils.zig");
const yap_sandbox = @import("yap_sandbox.zig");

/// YAP Session Manager - Persistent storage using SQLite
pub const SessionManager = struct {
    allocator: std.mem.Allocator,
    db: *c.sqlite3,
    db_path: []const u8,

    pub fn init(allocator: std.mem.Allocator) !SessionManager {
        // Get data directory
        const data_dir = try utils.getDataDir(allocator);
        defer allocator.free(data_dir);

        // Ensure directory exists
        try utils.ensureDir(data_dir);

        // Database path
        const db_path = try std.fmt.allocPrint(
            allocator,
            "{s}/yap_sessions.db",
            .{data_dir},
        );
        errdefer allocator.free(db_path);

        // Open database
        var db: ?*c.sqlite3 = null;
        const result = c.sqlite3_open(db_path.ptr, &db);
        if (result != c.SQLITE_OK) {
            utils.logError("Failed to open YAP sessions database: {s}", .{c.sqlite3_errmsg(db)});
            return error.DatabaseOpenFailed;
        }

        var manager = SessionManager{
            .allocator = allocator,
            .db = db.?,
            .db_path = db_path,
        };

        // Initialize schema
        try manager.initSchema();

        return manager;
    }

    pub fn deinit(self: *SessionManager) void {
        _ = c.sqlite3_close(self.db);
        self.allocator.free(self.db_path);
    }

    /// Initialize database schema
    fn initSchema(self: *SessionManager) !void {
        const schema = @embedFile("yap_schema.sql");

        var err_msg: [*c]u8 = undefined;
        const result = c.sqlite3_exec(
            self.db,
            schema.ptr,
            null,
            null,
            &err_msg,
        );

        if (result != c.SQLITE_OK) {
            defer c.sqlite3_free(err_msg);
            utils.logError("Failed to initialize schema: {s}", .{err_msg});
            return error.SchemaInitFailed;
        }
    }

    /// Create a new session
    pub fn createSession(
        self: *SessionManager,
        yapping: []const u8,
        context: ?[]const u8,
        model: []const u8,
        ollama_url: []const u8,
    ) !i64 {
        const ts = std.posix.clock_gettime(std.posix.CLOCK.REALTIME) catch unreachable;
        const now = @as(i64, ts.sec);

        const sql =
            \\INSERT INTO sessions (created_at, updated_at, status, yapping, initial_context, llm_model, ollama_url)
            \\VALUES (?, ?, 'active', ?, ?, ?, ?)
        ;

        var stmt: ?*c.sqlite3_stmt = null;
        var result = c.sqlite3_prepare_v2(self.db, sql.ptr, -1, &stmt, null);
        if (result != c.SQLITE_OK) {
            return error.PrepareFailed;
        }
        defer _ = c.sqlite3_finalize(stmt);

        _ = c.sqlite3_bind_int64(stmt, 1, now);
        _ = c.sqlite3_bind_int64(stmt, 2, now);
        _ = c.sqlite3_bind_text(stmt, 3, yapping.ptr, @intCast(yapping.len), c.SQLITE_TRANSIENT);

        if (context) |ctx| {
            _ = c.sqlite3_bind_text(stmt, 4, ctx.ptr, @intCast(ctx.len), c.SQLITE_TRANSIENT);
        } else {
            _ = c.sqlite3_bind_null(stmt, 4);
        }

        _ = c.sqlite3_bind_text(stmt, 5, model.ptr, @intCast(model.len), c.SQLITE_TRANSIENT);
        _ = c.sqlite3_bind_text(stmt, 6, ollama_url.ptr, @intCast(ollama_url.len), c.SQLITE_TRANSIENT);

        result = c.sqlite3_step(stmt);
        if (result != c.SQLITE_DONE) {
            return error.InsertFailed;
        }

        return c.sqlite3_last_insert_rowid(self.db);
    }

    /// Add a revision to a session
    pub fn addRevision(
        self: *SessionManager,
        session_id: i64,
        revision_number: i32,
        text: []const u8,
        trigger_type: []const u8,
        trigger_context: ?[]const u8,
    ) !void {
        const ts = std.posix.clock_gettime(std.posix.CLOCK.REALTIME) catch unreachable;
        const now = @as(i64, ts.sec);
        const char_count = text.len;

        const sql =
            \\INSERT INTO revisions (session_id, created_at, revision_number, text, char_count, trigger_type, trigger_context)
            \\VALUES (?, ?, ?, ?, ?, ?, ?)
        ;

        var stmt: ?*c.sqlite3_stmt = null;
        var result = c.sqlite3_prepare_v2(self.db, sql.ptr, -1, &stmt, null);
        if (result != c.SQLITE_OK) return error.PrepareFailed;
        defer _ = c.sqlite3_finalize(stmt);

        _ = c.sqlite3_bind_int64(stmt, 1, session_id);
        _ = c.sqlite3_bind_int64(stmt, 2, now);
        _ = c.sqlite3_bind_int(stmt, 3, revision_number);
        _ = c.sqlite3_bind_text(stmt, 4, text.ptr, @intCast(text.len), c.SQLITE_TRANSIENT);
        _ = c.sqlite3_bind_int64(stmt, 5, @intCast(char_count));
        _ = c.sqlite3_bind_text(stmt, 6, trigger_type.ptr, @intCast(trigger_type.len), c.SQLITE_TRANSIENT);

        if (trigger_context) |ctx| {
            _ = c.sqlite3_bind_text(stmt, 7, ctx.ptr, @intCast(ctx.len), c.SQLITE_TRANSIENT);
        } else {
            _ = c.sqlite3_bind_null(stmt, 7);
        }

        result = c.sqlite3_step(stmt);
        if (result != c.SQLITE_DONE) return error.InsertFailed;
    }

    /// Complete a session (mark as completed and store final message)
    pub fn completeSession(self: *SessionManager, session_id: i64, final_message: []const u8) !void {
        const ts = std.posix.clock_gettime(std.posix.CLOCK.REALTIME) catch unreachable;
        const now = @as(i64, ts.sec);

        const sql =
            \\UPDATE sessions
            \\SET status = 'completed', final_message = ?, updated_at = ?
            \\WHERE id = ?
        ;

        var stmt: ?*c.sqlite3_stmt = null;
        var result = c.sqlite3_prepare_v2(self.db, sql.ptr, -1, &stmt, null);
        if (result != c.SQLITE_OK) return error.PrepareFailed;
        defer _ = c.sqlite3_finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, final_message.ptr, @intCast(final_message.len), c.SQLITE_TRANSIENT);
        _ = c.sqlite3_bind_int64(stmt, 2, now);
        _ = c.sqlite3_bind_int64(stmt, 3, session_id);

        result = c.sqlite3_step(stmt);
        if (result != c.SQLITE_DONE) return error.UpdateFailed;
    }

    /// Abandon a session (interrupted/cancelled)
    pub fn abandonSession(self: *SessionManager, session_id: i64) !void {
        const ts = std.posix.clock_gettime(std.posix.CLOCK.REALTIME) catch unreachable;
        const now = @as(i64, ts.sec);

        const sql =
            \\UPDATE sessions
            \\SET status = 'abandoned', updated_at = ?
            \\WHERE id = ?
        ;

        var stmt: ?*c.sqlite3_stmt = null;
        var result = c.sqlite3_prepare_v2(self.db, sql.ptr, -1, &stmt, null);
        if (result != c.SQLITE_OK) return error.PrepareFailed;
        defer _ = c.sqlite3_finalize(stmt);

        _ = c.sqlite3_bind_int64(stmt, 1, now);
        _ = c.sqlite3_bind_int64(stmt, 2, session_id);

        result = c.sqlite3_step(stmt);
        if (result != c.SQLITE_DONE) return error.UpdateFailed;
    }

    /// Get active session ID (if any)
    pub fn getActiveSessionId(self: *SessionManager) !?i64 {
        const sql = "SELECT id FROM sessions WHERE status = 'active' LIMIT 1";

        var stmt: ?*c.sqlite3_stmt = null;
        var result = c.sqlite3_prepare_v2(self.db, sql.ptr, -1, &stmt, null);
        if (result != c.SQLITE_OK) return error.PrepareFailed;
        defer _ = c.sqlite3_finalize(stmt);

        result = c.sqlite3_step(stmt);
        if (result == c.SQLITE_ROW) {
            return c.sqlite3_column_int64(stmt, 0);
        }

        return null;
    }

    /// Save sandbox to database
    pub fn saveSandbox(self: *SessionManager, session_id: i64, sandbox: *yap_sandbox.Sandbox) !void {
        // Save all revisions
        for (sandbox.revisions.items, 0..) |rev, i| {
            const trigger = if (i == 0) "initial" else "refine_request";
            try self.addRevision(
                session_id,
                @intCast(i + 1),
                rev.text,
                trigger,
                null,
            );
        }

        // Update session with revision count
        const update_sql = "UPDATE sessions SET refinement_count = ? WHERE id = ?";
        var stmt: ?*c.sqlite3_stmt = null;
        var result = c.sqlite3_prepare_v2(self.db, update_sql.ptr, -1, &stmt, null);
        if (result != c.SQLITE_OK) return error.PrepareFailed;
        defer _ = c.sqlite3_finalize(stmt);

        _ = c.sqlite3_bind_int(stmt, 1, @intCast(sandbox.revisions.items.len));
        _ = c.sqlite3_bind_int64(stmt, 2, session_id);

        result = c.sqlite3_step(stmt);
        if (result != c.SQLITE_DONE) return error.UpdateFailed;
    }

    /// Restore sandbox from database (for session recovery)
    pub fn restoreSandbox(
        self: *SessionManager,
        session_id: i64,
        ollama_url: []const u8,
        system_prompt: []const u8,
        io: std.Io,
    ) !yap_sandbox.Sandbox {
        // Get session data
        const sql = "SELECT yapping, initial_context FROM sessions WHERE id = ?";
        var stmt: ?*c.sqlite3_stmt = null;
        var result = c.sqlite3_prepare_v2(self.db, sql.ptr, -1, &stmt, null);
        if (result != c.SQLITE_OK) return error.PrepareFailed;
        defer _ = c.sqlite3_finalize(stmt);

        _ = c.sqlite3_bind_int64(stmt, 1, session_id);

        result = c.sqlite3_step(stmt);
        if (result != c.SQLITE_ROW) return error.SessionNotFound;

        const yapping_text = c.sqlite3_column_text(stmt, 0);
        const yapping = std.mem.span(yapping_text);

        const context_text = c.sqlite3_column_text(stmt, 1);
        const context = if (context_text != null) std.mem.span(context_text) else null;

        // Create sandbox
        const sandbox = try yap_sandbox.Sandbox.init(
            self.allocator,
            yapping,
            context,
            ollama_url,
            system_prompt,
            io,
        );

        // Load revisions (implementation simplified - would need to fetch and restore)
        // This is a placeholder for full restoration logic

        return sandbox;
    }

    /// Search past sessions by text
    pub fn searchSessions(self: *SessionManager, query: []const u8, limit: i32) !void {
        const sql =
            \\SELECT s.id, s.created_at, s.yapping, s.final_message
            \\FROM sessions_fts f
            \\JOIN sessions s ON f.rowid = s.id
            \\WHERE sessions_fts MATCH ?
            \\ORDER BY rank
            \\LIMIT ?
        ;

        var stmt: ?*c.sqlite3_stmt = null;
        const result = c.sqlite3_prepare_v2(self.db, sql.ptr, -1, &stmt, null);
        if (result != c.SQLITE_OK) return error.PrepareFailed;
        defer _ = c.sqlite3_finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, query.ptr, @intCast(query.len), c.SQLITE_TRANSIENT);
        _ = c.sqlite3_bind_int(stmt, 2, limit);

        while (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
            const id = c.sqlite3_column_int64(stmt, 0);
            const created = c.sqlite3_column_int64(stmt, 1);
            const yapping = std.mem.span(c.sqlite3_column_text(stmt, 2));
            const final = c.sqlite3_column_text(stmt, 3);

            std.debug.print("\n[Session {d}] Created: {d}\n", .{ id, created });
            std.debug.print("Yapping: {s}\n", .{yapping});
            if (final != null) {
                std.debug.print("Final: {s}\n", .{std.mem.span(final)});
            }
        }
    }
};
