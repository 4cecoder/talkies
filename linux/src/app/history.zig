//! Persistent transcript history in SQLite.
//!
//! `$XDG_DATA_HOME/talkies/history.sqlite` (directory 0700, file 0600) holds
//! every final transcript while "Save transcript history" is on, until the
//! user deletes it; nothing expires. The schema (history_schema.sql) is shared
//! with the other clients. Migrations are keyed on `PRAGMA user_version`.
//!
//! Transcript text never goes to the log: errors name the operation only.

const std = @import("std");
const c = @import("c_sqlite3");
const utils = @import("core").utils;

pub const file_name = "history.sqlite";
/// HUD and CLI page size.
pub const page_size: u32 = 50;

/// `migrations[i]` upgrades a database from user_version i to i + 1.
const migrations = [_][:0]const u8{
    @embedFile("history_schema.sql"),
};
pub const schema_version: i64 = migrations.len;

pub const NewEntry = struct {
    /// Final text that was inserted.
    text: []const u8,
    /// Recognizer output before cleanup; stored as NULL when equal to `text`.
    raw_text: ?[]const u8 = null,
    duration_ms: ?i64 = null,
    /// "phonon" or "whisper".
    runtime: ?[]const u8 = null,
    language: ?[]const u8 = null,
    /// Defaults to now.
    created_at_ms: ?i64 = null,
};

pub const Entry = struct {
    id: i64,
    uuid: []const u8,
    created_at_ms: i64,
    text: []const u8,
    raw_text: ?[]const u8,
    duration_ms: ?i64,
    runtime: ?[]const u8,
    language: ?[]const u8,
};

/// Entries newest first; every string is owned by `arena`.
pub const Page = struct {
    arena: std.heap.ArenaAllocator,
    entries: []Entry,
    /// More rows exist after this page.
    has_more: bool,

    pub fn deinit(self: *Page) void {
        self.arena.deinit();
    }
};

pub const Query = struct {
    /// Case-insensitive substring match on the text; null or empty = all.
    search: ?[]const u8 = null,
    offset: u32 = 0,
    limit: u32 = page_size,
};

pub const Store = struct {
    db: *c.sqlite3,

    /// Open (creating if needed) the history in the user's data directory.
    pub fn openDefault(allocator: std.mem.Allocator) !Store {
        const dir = try utils.getDataDir(allocator);
        defer allocator.free(dir);
        return open(allocator, dir);
    }

    /// Open `<dir>/history.sqlite`, creating the directory (0700) and the
    /// file (0600) first so SQLite never creates them with the umask.
    pub fn open(allocator: std.mem.Allocator, dir: []const u8) !Store {
        try utils.ensureDir(dir);
        try chmodPath(allocator, dir, 0o700);
        const path = try std.fmt.allocPrintSentinel(allocator, "{s}/{s}", .{ dir, file_name }, 0);
        defer allocator.free(path);
        if (std.Io.Dir.cwd().createFile(utils.io(), path, .{
            .exclusive = true,
            .permissions = @fromBackingInt(@as(u32, 0o600)),
        })) |file| {
            file.close(utils.io());
        } else |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        }
        // Tighten a file created by hand or by an older build.
        if (std.c.chmod(path.ptr, 0o600) != 0) return error.AccessDenied;

        var db: ?*c.sqlite3 = null;
        if (c.sqlite3_open_v2(path.ptr, &db, c.SQLITE_OPEN_READWRITE | c.SQLITE_OPEN_CREATE, null) != c.SQLITE_OK) {
            if (db) |handle| _ = c.sqlite3_close(handle);
            utils.logError("Could not open transcript history", .{});
            return error.HistoryOpenFailed;
        }
        var store: Store = .{ .db = db.? };
        errdefer store.close();
        // The daemon and `talkies history` may use the file at the same time.
        _ = c.sqlite3_busy_timeout(store.db, 2000);
        // WAL journal (its -wal/-shm files inherit the 0600 mode); deleted
        // rows are overwritten instead of lingering in free pages.
        try store.exec("PRAGMA journal_mode = WAL; PRAGMA secure_delete = ON;");
        try store.migrate();
        return store;
    }

    pub fn close(self: *Store) void {
        _ = c.sqlite3_close(self.db);
    }

    fn exec(self: *Store, sql: [:0]const u8) !void {
        if (c.sqlite3_exec(self.db, sql.ptr, null, null, null) != c.SQLITE_OK) {
            utils.logError("Transcript history: {s}", .{c.sqlite3_errmsg(self.db)});
            return error.HistoryQueryFailed;
        }
    }

    fn prepare(self: *Store, sql: [:0]const u8) !*c.sqlite3_stmt {
        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(self.db, sql.ptr, -1, &stmt, null) != c.SQLITE_OK) return error.HistoryQueryFailed;
        return stmt.?;
    }

    pub fn userVersion(self: *Store) !i64 {
        const stmt = try self.prepare("PRAGMA user_version");
        defer _ = c.sqlite3_finalize(stmt);
        if (c.sqlite3_step(stmt) != c.SQLITE_ROW) return error.HistoryQueryFailed;
        return c.sqlite3_column_int64(stmt, 0);
    }

    /// Apply every migration above the file's user_version, each in its own
    /// transaction. A file from a newer Talkies is left untouched.
    fn migrate(self: *Store) !void {
        const current = try self.userVersion();
        if (current > schema_version) return error.HistoryFromNewerVersion;
        var version = current;
        while (version < schema_version) : (version += 1) {
            try self.exec("BEGIN IMMEDIATE");
            errdefer self.exec("ROLLBACK") catch {};
            try self.exec(migrations[@intCast(version)]);
            var buf: [64]u8 = undefined;
            try self.exec(try std.fmt.bufPrintSentinel(&buf, "PRAGMA user_version = {d}", .{version + 1}, 0));
            try self.exec("COMMIT");
        }
    }

    /// Store one transcript. Returns its row id.
    pub fn insert(self: *Store, entry: NewEntry) !i64 {
        const stmt = try self.prepare(
            \\INSERT INTO transcripts (uuid, created_at, text, raw_text, duration_ms, runtime, language)
            \\VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
        );
        defer _ = c.sqlite3_finalize(stmt);
        var bytes: [16]u8 = undefined;
        utils.io().random(&bytes);
        const uuid = formatUuidV4(bytes);
        bindText(stmt, 1, &uuid);
        _ = c.sqlite3_bind_int64(stmt, 2, entry.created_at_ms orelse nowMilliseconds());
        bindText(stmt, 3, entry.text);
        const raw = if (entry.raw_text) |r| (if (std.mem.eql(u8, r, entry.text)) null else r) else null;
        bindOptionalText(stmt, 4, raw);
        if (entry.duration_ms) |ms| _ = c.sqlite3_bind_int64(stmt, 5, ms) else _ = c.sqlite3_bind_null(stmt, 5);
        bindOptionalText(stmt, 6, entry.runtime);
        bindOptionalText(stmt, 7, if (entry.language) |l| (if (l.len == 0) null else l) else null);
        if (c.sqlite3_step(stmt) != c.SQLITE_DONE) return error.HistoryInsertFailed;
        return c.sqlite3_last_insert_rowid(self.db);
    }

    /// One page of entries, newest first.
    pub fn list(self: *Store, allocator: std.mem.Allocator, query: Query) !Page {
        const stmt = try self.prepare(
            \\SELECT id, uuid, created_at, text, raw_text, duration_ms, runtime, language
            \\FROM transcripts
            \\WHERE ?1 IS NULL OR text LIKE ?1 ESCAPE '\'
            \\ORDER BY created_at DESC, id DESC
            \\LIMIT ?2 OFFSET ?3
        );
        defer _ = c.sqlite3_finalize(stmt);

        var page: Page = .{ .arena = std.heap.ArenaAllocator.init(allocator), .entries = &.{}, .has_more = false };
        errdefer page.deinit();
        const a = page.arena.allocator();
        const search = query.search orelse "";
        if (search.len > 0) bindText(stmt, 1, try likePattern(a, search)) else _ = c.sqlite3_bind_null(stmt, 1);
        // One extra row tells whether another page exists.
        _ = c.sqlite3_bind_int64(stmt, 2, @as(i64, query.limit) + 1);
        _ = c.sqlite3_bind_int64(stmt, 3, query.offset);

        var entries: std.ArrayList(Entry) = .empty;
        while (true) {
            const rc = c.sqlite3_step(stmt);
            if (rc == c.SQLITE_DONE) break;
            if (rc != c.SQLITE_ROW) return error.HistoryQueryFailed;
            if (entries.items.len == query.limit) {
                page.has_more = true;
                break;
            }
            try entries.append(a, .{
                .id = c.sqlite3_column_int64(stmt, 0),
                .uuid = try columnText(a, stmt, 1) orelse "",
                .created_at_ms = c.sqlite3_column_int64(stmt, 2),
                .text = try columnText(a, stmt, 3) orelse "",
                .raw_text = try columnText(a, stmt, 4),
                .duration_ms = if (c.sqlite3_column_type(stmt, 5) == c.SQLITE_NULL) null else c.sqlite3_column_int64(stmt, 5),
                .runtime = try columnText(a, stmt, 6),
                .language = try columnText(a, stmt, 7),
            });
        }
        page.entries = entries.items;
        return page;
    }

    pub fn count(self: *Store) !u64 {
        const stmt = try self.prepare("SELECT count(*) FROM transcripts");
        defer _ = c.sqlite3_finalize(stmt);
        if (c.sqlite3_step(stmt) != c.SQLITE_ROW) return error.HistoryQueryFailed;
        return @intCast(c.sqlite3_column_int64(stmt, 0));
    }

    /// Returns false when no entry has this id.
    pub fn delete(self: *Store, id: i64) !bool {
        const stmt = try self.prepare("DELETE FROM transcripts WHERE id = ?1");
        defer _ = c.sqlite3_finalize(stmt);
        _ = c.sqlite3_bind_int64(stmt, 1, id);
        if (c.sqlite3_step(stmt) != c.SQLITE_DONE) return error.HistoryDeleteFailed;
        return c.sqlite3_changes(self.db) > 0;
    }

    /// Delete everything, then VACUUM and truncate the WAL so no old text
    /// stays on disk.
    pub fn clear(self: *Store) !void {
        try self.exec("DELETE FROM transcripts");
        try self.exec("VACUUM");
        try self.exec("PRAGMA wal_checkpoint(TRUNCATE)");
    }
};

/// SQLITE_STATIC: every bound buffer outlives the statement's last step.
/// (SQLITE_TRANSIENT's -1 function pointer does not translate on aarch64.)
fn bindText(stmt: *c.sqlite3_stmt, index: c_int, text: []const u8) void {
    _ = c.sqlite3_bind_text(stmt, index, text.ptr, @intCast(text.len), null);
}

fn bindOptionalText(stmt: *c.sqlite3_stmt, index: c_int, text: ?[]const u8) void {
    if (text) |t| bindText(stmt, index, t) else _ = c.sqlite3_bind_null(stmt, index);
}

fn columnText(allocator: std.mem.Allocator, stmt: *c.sqlite3_stmt, index: c_int) !?[]const u8 {
    if (c.sqlite3_column_type(stmt, index) == c.SQLITE_NULL) return null;
    const ptr = c.sqlite3_column_text(stmt, index) orelse return null;
    const len: usize = @intCast(c.sqlite3_column_bytes(stmt, index));
    return try allocator.dupe(u8, ptr[0..len]);
}

fn chmodPath(allocator: std.mem.Allocator, path: []const u8, mode: std.c.mode_t) !void {
    const path_z = try utils.dupeZ(allocator, path);
    defer allocator.free(path_z);
    if (std.c.chmod(path_z.ptr, mode) != 0) return error.AccessDenied;
}

fn nowMilliseconds() i64 {
    return std.Io.Timestamp.now(utils.io(), .real).toMilliseconds();
}

/// `%term%` with LIKE's wildcards in `term` escaped by backslash.
fn likePattern(allocator: std.mem.Allocator, term: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    try out.append(allocator, '%');
    for (term) |ch| {
        if (ch == '%' or ch == '_' or ch == '\\') try out.append(allocator, '\\');
        try out.append(allocator, ch);
    }
    try out.append(allocator, '%');
    return out.toOwnedSlice(allocator);
}

/// RFC 9562 version 4 (random) UUID in lowercase from 16 random bytes.
pub fn formatUuidV4(random_bytes: [16]u8) [36]u8 {
    var bytes = random_bytes;
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    const hex = std.fmt.bytesToHex(bytes, .lower);
    var out: [36]u8 = undefined;
    @memcpy(out[0..8], hex[0..8]);
    out[8] = '-';
    @memcpy(out[9..13], hex[8..12]);
    out[13] = '-';
    @memcpy(out[14..18], hex[12..16]);
    out[18] = '-';
    @memcpy(out[19..23], hex[16..20]);
    out[23] = '-';
    @memcpy(out[24..36], hex[20..32]);
    return out;
}

/// `talkies history --json`: an array of entries with every column.
pub fn writeJson(writer: *std.Io.Writer, entries: []const Entry) !void {
    try writer.writeAll("[");
    for (entries, 0..) |entry, i| {
        if (i > 0) try writer.writeAll(",");
        try writer.print("\n  {f}", .{std.json.fmt(.{
            .id = entry.id,
            .uuid = entry.uuid,
            .created_at = entry.created_at_ms,
            .text = entry.text,
            .raw_text = entry.raw_text,
            .duration_ms = entry.duration_ms,
            .runtime = entry.runtime,
            .language = entry.language,
        }, .{})});
    }
    try writer.writeAll(if (entries.len > 0) "\n]\n" else "]\n");
}

// ---------------------------------------------------------------------
// Tests (each uses its own temporary directory, never the user's data)
// ---------------------------------------------------------------------

const TestDir = struct {
    tmp: std.testing.TmpDir,
    path: []u8,

    fn init() !TestDir {
        var tmp = std.testing.tmpDir(.{});
        errdefer tmp.cleanup();
        const base = try tmp.dir.realPathFileAlloc(utils.io(), ".", std.testing.allocator);
        defer std.testing.allocator.free(base);
        return .{ .tmp = tmp, .path = try std.fmt.allocPrint(std.testing.allocator, "{s}/talkies", .{base}) };
    }

    fn deinit(self: *TestDir) void {
        std.testing.allocator.free(self.path);
        self.tmp.cleanup();
    }
};

fn modeOf(path: []const u8) !u32 {
    const stat = try std.Io.Dir.cwd().statFile(utils.io(), path, .{});
    return @intCast(stat.permissions.toMode() & 0o777);
}

test "open creates a private directory and file, migrates to v1 in WAL mode" {
    var dir = try TestDir.init();
    defer dir.deinit();
    var store = try Store.open(std.testing.allocator, dir.path);
    defer store.close();

    try std.testing.expectEqual(schema_version, try store.userVersion());
    try std.testing.expectEqual(@as(u32, 0o700), try modeOf(dir.path));
    const db_path = try std.fmt.allocPrint(std.testing.allocator, "{s}/{s}", .{ dir.path, file_name });
    defer std.testing.allocator.free(db_path);
    try std.testing.expectEqual(@as(u32, 0o600), try modeOf(db_path));

    const stmt = try store.prepare("PRAGMA journal_mode");
    defer _ = c.sqlite3_finalize(stmt);
    try std.testing.expectEqual(c.SQLITE_ROW, c.sqlite3_step(stmt));
    try std.testing.expectEqualStrings("wal", std.mem.span(c.sqlite3_column_text(stmt, 0)));
}

test "reopening keeps entries and does not re-run migrations" {
    var dir = try TestDir.init();
    defer dir.deinit();
    {
        var store = try Store.open(std.testing.allocator, dir.path);
        defer store.close();
        _ = try store.insert(.{ .text = "kept" });
    }
    var store = try Store.open(std.testing.allocator, dir.path);
    defer store.close();
    try std.testing.expectEqual(@as(u64, 1), try store.count());
    try std.testing.expectEqual(@as(i64, 1), try store.userVersion());
}

test "a database from a newer schema is refused, not modified" {
    var dir = try TestDir.init();
    defer dir.deinit();
    {
        var store = try Store.open(std.testing.allocator, dir.path);
        defer store.close();
        try store.exec("PRAGMA user_version = 99");
    }
    try std.testing.expectError(error.HistoryFromNewerVersion, Store.open(std.testing.allocator, dir.path));
}

test "insert stores every column and drops raw_text equal to text" {
    var dir = try TestDir.init();
    defer dir.deinit();
    var store = try Store.open(std.testing.allocator, dir.path);
    defer store.close();

    _ = try store.insert(.{ .text = "Hello, world.", .raw_text = "hello world", .duration_ms = 1500, .runtime = "phonon", .language = "en", .created_at_ms = 1_000 });
    _ = try store.insert(.{ .text = "same", .raw_text = "same", .runtime = "whisper", .language = "", .created_at_ms = 2_000 });

    var page = try store.list(std.testing.allocator, .{});
    defer page.deinit();
    try std.testing.expectEqual(@as(usize, 2), page.entries.len);
    const plain = page.entries[0];
    try std.testing.expectEqualStrings("same", plain.text);
    try std.testing.expect(plain.raw_text == null);
    try std.testing.expect(plain.duration_ms == null);
    try std.testing.expect(plain.language == null);
    const cleaned = page.entries[1];
    try std.testing.expectEqualStrings("Hello, world.", cleaned.text);
    try std.testing.expectEqualStrings("hello world", cleaned.raw_text.?);
    try std.testing.expectEqual(@as(i64, 1500), cleaned.duration_ms.?);
    try std.testing.expectEqualStrings("phonon", cleaned.runtime.?);
    try std.testing.expectEqualStrings("en", cleaned.language.?);
    try std.testing.expectEqual(@as(i64, 1_000), cleaned.created_at_ms);
    // Each row gets its own lowercase v4 UUID.
    try std.testing.expectEqual(@as(usize, 36), cleaned.uuid.len);
    try std.testing.expectEqual(@as(u8, '4'), cleaned.uuid[14]);
    try std.testing.expect(!std.mem.eql(u8, plain.uuid, cleaned.uuid));
}

test "list is newest first and pages with has_more" {
    var dir = try TestDir.init();
    defer dir.deinit();
    var store = try Store.open(std.testing.allocator, dir.path);
    defer store.close();
    for (0..5) |i| {
        var buf: [16]u8 = undefined;
        _ = try store.insert(.{ .text = try std.fmt.bufPrint(&buf, "entry {d}", .{i}), .created_at_ms = @intCast(i * 1000) });
    }
    // Same timestamp: the later row wins the tie.
    _ = try store.insert(.{ .text = "entry 5", .created_at_ms = 4000 });

    var first = try store.list(std.testing.allocator, .{ .limit = 4 });
    defer first.deinit();
    try std.testing.expect(first.has_more);
    try std.testing.expectEqual(@as(usize, 4), first.entries.len);
    try std.testing.expectEqualStrings("entry 5", first.entries[0].text);
    try std.testing.expectEqualStrings("entry 4", first.entries[1].text);
    try std.testing.expectEqualStrings("entry 2", first.entries[3].text);

    var second = try store.list(std.testing.allocator, .{ .limit = 4, .offset = 4 });
    defer second.deinit();
    try std.testing.expect(!second.has_more);
    try std.testing.expectEqual(@as(usize, 2), second.entries.len);
    try std.testing.expectEqualStrings("entry 0", second.entries[1].text);
}

test "search is case-insensitive and treats LIKE wildcards literally" {
    var dir = try TestDir.init();
    defer dir.deinit();
    var store = try Store.open(std.testing.allocator, dir.path);
    defer store.close();
    _ = try store.insert(.{ .text = "Meeting with Talkies team" });
    _ = try store.insert(.{ .text = "grocery list" });
    _ = try store.insert(.{ .text = "100% done" });
    _ = try store.insert(.{ .text = "1000 done" });
    _ = try store.insert(.{ .text = "it's a quote'); DROP TABLE transcripts; --" });

    var talkies = try store.list(std.testing.allocator, .{ .search = "TALKIES" });
    defer talkies.deinit();
    try std.testing.expectEqual(@as(usize, 1), talkies.entries.len);
    try std.testing.expectEqualStrings("Meeting with Talkies team", talkies.entries[0].text);

    var percent = try store.list(std.testing.allocator, .{ .search = "0%" });
    defer percent.deinit();
    try std.testing.expectEqual(@as(usize, 1), percent.entries.len);
    try std.testing.expectEqualStrings("100% done", percent.entries[0].text);

    var injected = try store.list(std.testing.allocator, .{ .search = "'); DROP" });
    defer injected.deinit();
    try std.testing.expectEqual(@as(usize, 1), injected.entries.len);
    try std.testing.expectEqual(@as(u64, 5), try store.count());

    var none = try store.list(std.testing.allocator, .{ .search = "nothing like this" });
    defer none.deinit();
    try std.testing.expectEqual(@as(usize, 0), none.entries.len);
}

test "delete removes one entry and clear removes all" {
    var dir = try TestDir.init();
    defer dir.deinit();
    var store = try Store.open(std.testing.allocator, dir.path);
    defer store.close();
    const first = try store.insert(.{ .text = "one" });
    _ = try store.insert(.{ .text = "two" });
    _ = try store.insert(.{ .text = "three" });

    try std.testing.expect(try store.delete(first));
    try std.testing.expect(!try store.delete(first));
    try std.testing.expectEqual(@as(u64, 2), try store.count());

    try store.clear();
    try std.testing.expectEqual(@as(u64, 0), try store.count());
    // Still usable after VACUUM.
    _ = try store.insert(.{ .text = "four" });
    try std.testing.expectEqual(@as(u64, 1), try store.count());
}

test "UUIDv4 formatting sets the version and variant bits" {
    const uuid = formatUuidV4(@splat(0xff));
    try std.testing.expectEqualStrings("ffffffff-ffff-4fff-bfff-ffffffffffff", &uuid);
    const zero = formatUuidV4(@splat(0));
    try std.testing.expectEqualStrings("00000000-0000-4000-8000-000000000000", &zero);
}

test "JSON output includes the uuid and nulls for missing columns" {
    var out: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer out.deinit();
    try writeJson(&out.writer, &.{.{
        .id = 7,
        .uuid = "00000000-0000-4000-8000-000000000000",
        .created_at_ms = 1_700_000_000_000,
        .text = "say \"hi\"",
        .raw_text = null,
        .duration_ms = 900,
        .runtime = "whisper",
        .language = null,
    }});
    try std.testing.expectEqualStrings(
        "[\n  {\"id\":7,\"uuid\":\"00000000-0000-4000-8000-000000000000\",\"created_at\":1700000000000," ++
            "\"text\":\"say \\\"hi\\\"\",\"raw_text\":null,\"duration_ms\":900,\"runtime\":\"whisper\",\"language\":null}\n]\n",
        out.written(),
    );
    var empty: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer empty.deinit();
    try writeJson(&empty.writer, &.{});
    try std.testing.expectEqualStrings("[]\n", empty.written());
}
