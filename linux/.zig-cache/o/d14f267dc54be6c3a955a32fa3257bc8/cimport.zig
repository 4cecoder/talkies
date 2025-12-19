const __root = @This();
pub const __builtin = @import("std").zig.c_translation.builtins;
pub const __helpers = @import("std").zig.c_translation.helpers;

pub const struct___va_list_tag_1 = extern struct {
    unnamed_0: c_uint = 0,
    unnamed_1: c_uint = 0,
    unnamed_2: ?*anyopaque = null,
    unnamed_3: ?*anyopaque = null,
};
pub const __builtin_va_list = [1]struct___va_list_tag_1;
pub const va_list = __builtin_va_list;
pub const __gnuc_va_list = __builtin_va_list;
pub const sqlite3_version: [*c]const u8 = @extern([*c]const u8, .{
    .name = "sqlite3_version",
});
pub extern fn sqlite3_libversion() [*c]const u8;
pub extern fn sqlite3_sourceid() [*c]const u8;
pub extern fn sqlite3_libversion_number() c_int;
pub extern fn sqlite3_compileoption_used(zOptName: [*c]const u8) c_int;
pub extern fn sqlite3_compileoption_get(N: c_int) [*c]const u8;
pub extern fn sqlite3_threadsafe() c_int;
pub const struct_sqlite3 = opaque {
    pub const sqlite3_close = __root.sqlite3_close;
    pub const sqlite3_close_v2 = __root.sqlite3_close_v2;
    pub const sqlite3_exec = __root.sqlite3_exec;
    pub const sqlite3_db_config = __root.sqlite3_db_config;
    pub const sqlite3_extended_result_codes = __root.sqlite3_extended_result_codes;
    pub const sqlite3_last_insert_rowid = __root.sqlite3_last_insert_rowid;
    pub const sqlite3_set_last_insert_rowid = __root.sqlite3_set_last_insert_rowid;
    pub const sqlite3_changes = __root.sqlite3_changes;
    pub const sqlite3_changes64 = __root.sqlite3_changes64;
    pub const sqlite3_total_changes = __root.sqlite3_total_changes;
    pub const sqlite3_total_changes64 = __root.sqlite3_total_changes64;
    pub const sqlite3_interrupt = __root.sqlite3_interrupt;
    pub const sqlite3_is_interrupted = __root.sqlite3_is_interrupted;
    pub const sqlite3_busy_handler = __root.sqlite3_busy_handler;
    pub const sqlite3_busy_timeout = __root.sqlite3_busy_timeout;
    pub const sqlite3_setlk_timeout = __root.sqlite3_setlk_timeout;
    pub const sqlite3_get_table = __root.sqlite3_get_table;
    pub const sqlite3_set_authorizer = __root.sqlite3_set_authorizer;
    pub const sqlite3_trace = __root.sqlite3_trace;
    pub const sqlite3_profile = __root.sqlite3_profile;
    pub const sqlite3_trace_v2 = __root.sqlite3_trace_v2;
    pub const sqlite3_progress_handler = __root.sqlite3_progress_handler;
    pub const sqlite3_errcode = __root.sqlite3_errcode;
    pub const sqlite3_extended_errcode = __root.sqlite3_extended_errcode;
    pub const sqlite3_errmsg = __root.sqlite3_errmsg;
    pub const sqlite3_errmsg16 = __root.sqlite3_errmsg16;
    pub const sqlite3_error_offset = __root.sqlite3_error_offset;
    pub const sqlite3_limit = __root.sqlite3_limit;
    pub const sqlite3_prepare = __root.sqlite3_prepare;
    pub const sqlite3_prepare_v2 = __root.sqlite3_prepare_v2;
    pub const sqlite3_prepare_v3 = __root.sqlite3_prepare_v3;
    pub const sqlite3_prepare16 = __root.sqlite3_prepare16;
    pub const sqlite3_prepare16_v2 = __root.sqlite3_prepare16_v2;
    pub const sqlite3_prepare16_v3 = __root.sqlite3_prepare16_v3;
    pub const sqlite3_create_function = __root.sqlite3_create_function;
    pub const sqlite3_create_function16 = __root.sqlite3_create_function16;
    pub const sqlite3_create_function_v2 = __root.sqlite3_create_function_v2;
    pub const sqlite3_create_window_function = __root.sqlite3_create_window_function;
    pub const sqlite3_get_clientdata = __root.sqlite3_get_clientdata;
    pub const sqlite3_set_clientdata = __root.sqlite3_set_clientdata;
    pub const sqlite3_create_collation = __root.sqlite3_create_collation;
    pub const sqlite3_create_collation_v2 = __root.sqlite3_create_collation_v2;
    pub const sqlite3_create_collation16 = __root.sqlite3_create_collation16;
    pub const sqlite3_collation_needed = __root.sqlite3_collation_needed;
    pub const sqlite3_collation_needed16 = __root.sqlite3_collation_needed16;
    pub const sqlite3_get_autocommit = __root.sqlite3_get_autocommit;
    pub const sqlite3_db_name = __root.sqlite3_db_name;
    pub const sqlite3_db_filename = __root.sqlite3_db_filename;
    pub const sqlite3_db_readonly = __root.sqlite3_db_readonly;
    pub const sqlite3_txn_state = __root.sqlite3_txn_state;
    pub const sqlite3_next_stmt = __root.sqlite3_next_stmt;
    pub const sqlite3_commit_hook = __root.sqlite3_commit_hook;
    pub const sqlite3_rollback_hook = __root.sqlite3_rollback_hook;
    pub const sqlite3_autovacuum_pages = __root.sqlite3_autovacuum_pages;
    pub const sqlite3_update_hook = __root.sqlite3_update_hook;
    pub const sqlite3_db_release_memory = __root.sqlite3_db_release_memory;
    pub const sqlite3_table_column_metadata = __root.sqlite3_table_column_metadata;
    pub const sqlite3_load_extension = __root.sqlite3_load_extension;
    pub const sqlite3_enable_load_extension = __root.sqlite3_enable_load_extension;
    pub const sqlite3_create_module = __root.sqlite3_create_module;
    pub const sqlite3_create_module_v2 = __root.sqlite3_create_module_v2;
    pub const sqlite3_drop_modules = __root.sqlite3_drop_modules;
    pub const sqlite3_declare_vtab = __root.sqlite3_declare_vtab;
    pub const sqlite3_overload_function = __root.sqlite3_overload_function;
    pub const sqlite3_blob_open = __root.sqlite3_blob_open;
    pub const sqlite3_db_mutex = __root.sqlite3_db_mutex;
    pub const sqlite3_file_control = __root.sqlite3_file_control;
    pub const sqlite3_str_new = __root.sqlite3_str_new;
    pub const sqlite3_db_status = __root.sqlite3_db_status;
    pub const sqlite3_backup_init = __root.sqlite3_backup_init;
    pub const sqlite3_unlock_notify = __root.sqlite3_unlock_notify;
    pub const sqlite3_wal_hook = __root.sqlite3_wal_hook;
    pub const sqlite3_wal_autocheckpoint = __root.sqlite3_wal_autocheckpoint;
    pub const sqlite3_wal_checkpoint = __root.sqlite3_wal_checkpoint;
    pub const sqlite3_wal_checkpoint_v2 = __root.sqlite3_wal_checkpoint_v2;
    pub const sqlite3_vtab_config = __root.sqlite3_vtab_config;
    pub const sqlite3_vtab_on_conflict = __root.sqlite3_vtab_on_conflict;
    pub const sqlite3_db_cacheflush = __root.sqlite3_db_cacheflush;
    pub const sqlite3_system_errno = __root.sqlite3_system_errno;
    pub const sqlite3_snapshot_get = __root.sqlite3_snapshot_get;
    pub const sqlite3_snapshot_open = __root.sqlite3_snapshot_open;
    pub const sqlite3_snapshot_recover = __root.sqlite3_snapshot_recover;
    pub const sqlite3_serialize = __root.sqlite3_serialize;
    pub const sqlite3_deserialize = __root.sqlite3_deserialize;
    pub const sqlite3_rtree_geometry_callback = __root.sqlite3_rtree_geometry_callback;
    pub const sqlite3_rtree_query_callback = __root.sqlite3_rtree_query_callback;
    pub const close = __root.sqlite3_close;
    pub const v2 = __root.sqlite3_close_v2;
    pub const exec = __root.sqlite3_exec;
    pub const config = __root.sqlite3_db_config;
    pub const codes = __root.sqlite3_extended_result_codes;
    pub const rowid = __root.sqlite3_last_insert_rowid;
    pub const changes = __root.sqlite3_changes;
    pub const changes64 = __root.sqlite3_changes64;
    pub const interrupt = __root.sqlite3_interrupt;
    pub const interrupted = __root.sqlite3_is_interrupted;
    pub const handler = __root.sqlite3_busy_handler;
    pub const timeout = __root.sqlite3_busy_timeout;
    pub const table = __root.sqlite3_get_table;
    pub const authorizer = __root.sqlite3_set_authorizer;
    pub const trace = __root.sqlite3_trace;
    pub const profile = __root.sqlite3_profile;
    pub const errcode = __root.sqlite3_errcode;
    pub const errmsg = __root.sqlite3_errmsg;
    pub const errmsg16 = __root.sqlite3_errmsg16;
    pub const offset = __root.sqlite3_error_offset;
    pub const limit = __root.sqlite3_limit;
    pub const prepare = __root.sqlite3_prepare;
    pub const v3 = __root.sqlite3_prepare_v3;
    pub const prepare16 = __root.sqlite3_prepare16;
    pub const function = __root.sqlite3_create_function;
    pub const function16 = __root.sqlite3_create_function16;
    pub const clientdata = __root.sqlite3_get_clientdata;
    pub const collation = __root.sqlite3_create_collation;
    pub const collation16 = __root.sqlite3_create_collation16;
    pub const needed = __root.sqlite3_collation_needed;
    pub const needed16 = __root.sqlite3_collation_needed16;
    pub const autocommit = __root.sqlite3_get_autocommit;
    pub const name = __root.sqlite3_db_name;
    pub const filename = __root.sqlite3_db_filename;
    pub const readonly = __root.sqlite3_db_readonly;
    pub const state = __root.sqlite3_txn_state;
    pub const stmt = __root.sqlite3_next_stmt;
    pub const hook = __root.sqlite3_commit_hook;
    pub const pages = __root.sqlite3_autovacuum_pages;
    pub const memory = __root.sqlite3_db_release_memory;
    pub const metadata = __root.sqlite3_table_column_metadata;
    pub const extension = __root.sqlite3_load_extension;
    pub const module = __root.sqlite3_create_module;
    pub const modules = __root.sqlite3_drop_modules;
    pub const vtab = __root.sqlite3_declare_vtab;
    pub const open = __root.sqlite3_blob_open;
    pub const mutex = __root.sqlite3_db_mutex;
    pub const control = __root.sqlite3_file_control;
    pub const new = __root.sqlite3_str_new;
    pub const status = __root.sqlite3_db_status;
    pub const init = __root.sqlite3_backup_init;
    pub const notify = __root.sqlite3_unlock_notify;
    pub const autocheckpoint = __root.sqlite3_wal_autocheckpoint;
    pub const checkpoint = __root.sqlite3_wal_checkpoint;
    pub const conflict = __root.sqlite3_vtab_on_conflict;
    pub const cacheflush = __root.sqlite3_db_cacheflush;
    pub const errno = __root.sqlite3_system_errno;
    pub const get = __root.sqlite3_snapshot_get;
    pub const recover = __root.sqlite3_snapshot_recover;
    pub const serialize = __root.sqlite3_serialize;
    pub const deserialize = __root.sqlite3_deserialize;
    pub const callback = __root.sqlite3_rtree_geometry_callback;
};
pub const sqlite3 = struct_sqlite3;
pub const sqlite_int64 = c_longlong;
pub const sqlite_uint64 = c_ulonglong;
pub const sqlite3_int64 = sqlite_int64;
pub const sqlite3_uint64 = sqlite_uint64;
pub extern fn sqlite3_close(?*sqlite3) c_int;
pub extern fn sqlite3_close_v2(?*sqlite3) c_int;
pub const sqlite3_callback = ?*const fn (?*anyopaque, c_int, [*c][*c]u8, [*c][*c]u8) callconv(.c) c_int;
pub extern fn sqlite3_exec(?*sqlite3, sql: [*c]const u8, callback: ?*const fn (?*anyopaque, c_int, [*c][*c]u8, [*c][*c]u8) callconv(.c) c_int, ?*anyopaque, errmsg: [*c][*c]u8) c_int;
pub const struct_sqlite3_io_methods = extern struct {
    iVersion: c_int = 0,
    xClose: ?*const fn ([*c]sqlite3_file) callconv(.c) c_int = null,
    xRead: ?*const fn ([*c]sqlite3_file, ?*anyopaque, iAmt: c_int, iOfst: sqlite3_int64) callconv(.c) c_int = null,
    xWrite: ?*const fn ([*c]sqlite3_file, ?*const anyopaque, iAmt: c_int, iOfst: sqlite3_int64) callconv(.c) c_int = null,
    xTruncate: ?*const fn ([*c]sqlite3_file, size: sqlite3_int64) callconv(.c) c_int = null,
    xSync: ?*const fn ([*c]sqlite3_file, flags: c_int) callconv(.c) c_int = null,
    xFileSize: ?*const fn ([*c]sqlite3_file, pSize: [*c]sqlite3_int64) callconv(.c) c_int = null,
    xLock: ?*const fn ([*c]sqlite3_file, c_int) callconv(.c) c_int = null,
    xUnlock: ?*const fn ([*c]sqlite3_file, c_int) callconv(.c) c_int = null,
    xCheckReservedLock: ?*const fn ([*c]sqlite3_file, pResOut: [*c]c_int) callconv(.c) c_int = null,
    xFileControl: ?*const fn ([*c]sqlite3_file, op: c_int, pArg: ?*anyopaque) callconv(.c) c_int = null,
    xSectorSize: ?*const fn ([*c]sqlite3_file) callconv(.c) c_int = null,
    xDeviceCharacteristics: ?*const fn ([*c]sqlite3_file) callconv(.c) c_int = null,
    xShmMap: ?*const fn ([*c]sqlite3_file, iPg: c_int, pgsz: c_int, c_int, [*c]?*volatile anyopaque) callconv(.c) c_int = null,
    xShmLock: ?*const fn ([*c]sqlite3_file, offset: c_int, n: c_int, flags: c_int) callconv(.c) c_int = null,
    xShmBarrier: ?*const fn ([*c]sqlite3_file) callconv(.c) void = null,
    xShmUnmap: ?*const fn ([*c]sqlite3_file, deleteFlag: c_int) callconv(.c) c_int = null,
    xFetch: ?*const fn ([*c]sqlite3_file, iOfst: sqlite3_int64, iAmt: c_int, pp: [*c]?*anyopaque) callconv(.c) c_int = null,
    xUnfetch: ?*const fn ([*c]sqlite3_file, iOfst: sqlite3_int64, p: ?*anyopaque) callconv(.c) c_int = null,
};
pub const struct_sqlite3_file = extern struct {
    pMethods: [*c]const struct_sqlite3_io_methods = null,
};
pub const sqlite3_file = struct_sqlite3_file;
pub const sqlite3_io_methods = struct_sqlite3_io_methods;
pub const struct_sqlite3_mutex = opaque {
    pub const sqlite3_mutex_free = __root.sqlite3_mutex_free;
    pub const sqlite3_mutex_enter = __root.sqlite3_mutex_enter;
    pub const sqlite3_mutex_try = __root.sqlite3_mutex_try;
    pub const sqlite3_mutex_leave = __root.sqlite3_mutex_leave;
    pub const sqlite3_mutex_held = __root.sqlite3_mutex_held;
    pub const sqlite3_mutex_notheld = __root.sqlite3_mutex_notheld;
    pub const free = __root.sqlite3_mutex_free;
    pub const enter = __root.sqlite3_mutex_enter;
    pub const @"try" = __root.sqlite3_mutex_try;
    pub const leave = __root.sqlite3_mutex_leave;
    pub const held = __root.sqlite3_mutex_held;
    pub const notheld = __root.sqlite3_mutex_notheld;
};
pub const sqlite3_mutex = struct_sqlite3_mutex;
pub const struct_sqlite3_api_routines = opaque {};
pub const sqlite3_api_routines = struct_sqlite3_api_routines;
pub const sqlite3_filename = [*c]const u8;
pub const sqlite3_syscall_ptr = ?*const fn () callconv(.c) void;
pub const struct_sqlite3_vfs = extern struct {
    iVersion: c_int = 0,
    szOsFile: c_int = 0,
    mxPathname: c_int = 0,
    pNext: [*c]sqlite3_vfs = null,
    zName: [*c]const u8 = null,
    pAppData: ?*anyopaque = null,
    xOpen: ?*const fn ([*c]sqlite3_vfs, zName: sqlite3_filename, [*c]sqlite3_file, flags: c_int, pOutFlags: [*c]c_int) callconv(.c) c_int = null,
    xDelete: ?*const fn ([*c]sqlite3_vfs, zName: [*c]const u8, syncDir: c_int) callconv(.c) c_int = null,
    xAccess: ?*const fn ([*c]sqlite3_vfs, zName: [*c]const u8, flags: c_int, pResOut: [*c]c_int) callconv(.c) c_int = null,
    xFullPathname: ?*const fn ([*c]sqlite3_vfs, zName: [*c]const u8, nOut: c_int, zOut: [*c]u8) callconv(.c) c_int = null,
    xDlOpen: ?*const fn ([*c]sqlite3_vfs, zFilename: [*c]const u8) callconv(.c) ?*anyopaque = null,
    xDlError: ?*const fn ([*c]sqlite3_vfs, nByte: c_int, zErrMsg: [*c]u8) callconv(.c) void = null,
    xDlSym: ?*const fn ([*c]sqlite3_vfs, ?*anyopaque, zSymbol: [*c]const u8) callconv(.c) ?*const fn () callconv(.c) void = null,
    xDlClose: ?*const fn ([*c]sqlite3_vfs, ?*anyopaque) callconv(.c) void = null,
    xRandomness: ?*const fn ([*c]sqlite3_vfs, nByte: c_int, zOut: [*c]u8) callconv(.c) c_int = null,
    xSleep: ?*const fn ([*c]sqlite3_vfs, microseconds: c_int) callconv(.c) c_int = null,
    xCurrentTime: ?*const fn ([*c]sqlite3_vfs, [*c]f64) callconv(.c) c_int = null,
    xGetLastError: ?*const fn ([*c]sqlite3_vfs, c_int, [*c]u8) callconv(.c) c_int = null,
    xCurrentTimeInt64: ?*const fn ([*c]sqlite3_vfs, [*c]sqlite3_int64) callconv(.c) c_int = null,
    xSetSystemCall: ?*const fn ([*c]sqlite3_vfs, zName: [*c]const u8, sqlite3_syscall_ptr) callconv(.c) c_int = null,
    xGetSystemCall: ?*const fn ([*c]sqlite3_vfs, zName: [*c]const u8) callconv(.c) sqlite3_syscall_ptr = null,
    xNextSystemCall: ?*const fn ([*c]sqlite3_vfs, zName: [*c]const u8) callconv(.c) [*c]const u8 = null,
    pub const sqlite3_vfs_register = __root.sqlite3_vfs_register;
    pub const sqlite3_vfs_unregister = __root.sqlite3_vfs_unregister;
    pub const register = __root.sqlite3_vfs_register;
    pub const unregister = __root.sqlite3_vfs_unregister;
};
pub const sqlite3_vfs = struct_sqlite3_vfs;
pub extern fn sqlite3_initialize() c_int;
pub extern fn sqlite3_shutdown() c_int;
pub extern fn sqlite3_os_init() c_int;
pub extern fn sqlite3_os_end() c_int;
pub extern fn sqlite3_config(c_int, ...) c_int;
pub extern fn sqlite3_db_config(?*sqlite3, op: c_int, ...) c_int;
pub const struct_sqlite3_mem_methods = extern struct {
    xMalloc: ?*const fn (c_int) callconv(.c) ?*anyopaque = null,
    xFree: ?*const fn (?*anyopaque) callconv(.c) void = null,
    xRealloc: ?*const fn (?*anyopaque, c_int) callconv(.c) ?*anyopaque = null,
    xSize: ?*const fn (?*anyopaque) callconv(.c) c_int = null,
    xRoundup: ?*const fn (c_int) callconv(.c) c_int = null,
    xInit: ?*const fn (?*anyopaque) callconv(.c) c_int = null,
    xShutdown: ?*const fn (?*anyopaque) callconv(.c) void = null,
    pAppData: ?*anyopaque = null,
};
pub const sqlite3_mem_methods = struct_sqlite3_mem_methods;
pub extern fn sqlite3_extended_result_codes(?*sqlite3, onoff: c_int) c_int;
pub extern fn sqlite3_last_insert_rowid(?*sqlite3) sqlite3_int64;
pub extern fn sqlite3_set_last_insert_rowid(?*sqlite3, sqlite3_int64) void;
pub extern fn sqlite3_changes(?*sqlite3) c_int;
pub extern fn sqlite3_changes64(?*sqlite3) sqlite3_int64;
pub extern fn sqlite3_total_changes(?*sqlite3) c_int;
pub extern fn sqlite3_total_changes64(?*sqlite3) sqlite3_int64;
pub extern fn sqlite3_interrupt(?*sqlite3) void;
pub extern fn sqlite3_is_interrupted(?*sqlite3) c_int;
pub extern fn sqlite3_complete(sql: [*c]const u8) c_int;
pub extern fn sqlite3_complete16(sql: ?*const anyopaque) c_int;
pub extern fn sqlite3_busy_handler(?*sqlite3, ?*const fn (?*anyopaque, c_int) callconv(.c) c_int, ?*anyopaque) c_int;
pub extern fn sqlite3_busy_timeout(?*sqlite3, ms: c_int) c_int;
pub extern fn sqlite3_setlk_timeout(?*sqlite3, ms: c_int, flags: c_int) c_int;
pub extern fn sqlite3_get_table(db: ?*sqlite3, zSql: [*c]const u8, pazResult: [*c][*c][*c]u8, pnRow: [*c]c_int, pnColumn: [*c]c_int, pzErrmsg: [*c][*c]u8) c_int;
pub extern fn sqlite3_free_table(result: [*c][*c]u8) void;
pub extern fn sqlite3_mprintf([*c]const u8, ...) [*c]u8;
pub extern fn sqlite3_vmprintf([*c]const u8, [*c]struct___va_list_tag_1) [*c]u8;
pub extern fn sqlite3_snprintf(c_int, [*c]u8, [*c]const u8, ...) [*c]u8;
pub extern fn sqlite3_vsnprintf(c_int, [*c]u8, [*c]const u8, [*c]struct___va_list_tag_1) [*c]u8;
pub extern fn sqlite3_malloc(c_int) ?*anyopaque;
pub extern fn sqlite3_malloc64(sqlite3_uint64) ?*anyopaque;
pub extern fn sqlite3_realloc(?*anyopaque, c_int) ?*anyopaque;
pub extern fn sqlite3_realloc64(?*anyopaque, sqlite3_uint64) ?*anyopaque;
pub extern fn sqlite3_free(?*anyopaque) void;
pub extern fn sqlite3_msize(?*anyopaque) sqlite3_uint64;
pub extern fn sqlite3_memory_used() sqlite3_int64;
pub extern fn sqlite3_memory_highwater(resetFlag: c_int) sqlite3_int64;
pub extern fn sqlite3_randomness(N: c_int, P: ?*anyopaque) void;
pub extern fn sqlite3_set_authorizer(?*sqlite3, xAuth: ?*const fn (?*anyopaque, c_int, [*c]const u8, [*c]const u8, [*c]const u8, [*c]const u8) callconv(.c) c_int, pUserData: ?*anyopaque) c_int;
pub extern fn sqlite3_trace(?*sqlite3, xTrace: ?*const fn (?*anyopaque, [*c]const u8) callconv(.c) void, ?*anyopaque) ?*anyopaque;
pub extern fn sqlite3_profile(?*sqlite3, xProfile: ?*const fn (?*anyopaque, [*c]const u8, sqlite3_uint64) callconv(.c) void, ?*anyopaque) ?*anyopaque;
pub extern fn sqlite3_trace_v2(?*sqlite3, uMask: c_uint, xCallback: ?*const fn (c_uint, ?*anyopaque, ?*anyopaque, ?*anyopaque) callconv(.c) c_int, pCtx: ?*anyopaque) c_int;
pub extern fn sqlite3_progress_handler(?*sqlite3, c_int, ?*const fn (?*anyopaque) callconv(.c) c_int, ?*anyopaque) void;
pub extern fn sqlite3_open(filename: [*c]const u8, ppDb: [*c]?*sqlite3) c_int;
pub extern fn sqlite3_open16(filename: ?*const anyopaque, ppDb: [*c]?*sqlite3) c_int;
pub extern fn sqlite3_open_v2(filename: [*c]const u8, ppDb: [*c]?*sqlite3, flags: c_int, zVfs: [*c]const u8) c_int;
pub extern fn sqlite3_uri_parameter(z: sqlite3_filename, zParam: [*c]const u8) [*c]const u8;
pub extern fn sqlite3_uri_boolean(z: sqlite3_filename, zParam: [*c]const u8, bDefault: c_int) c_int;
pub extern fn sqlite3_uri_int64(sqlite3_filename, [*c]const u8, sqlite3_int64) sqlite3_int64;
pub extern fn sqlite3_uri_key(z: sqlite3_filename, N: c_int) [*c]const u8;
pub extern fn sqlite3_filename_database(sqlite3_filename) [*c]const u8;
pub extern fn sqlite3_filename_journal(sqlite3_filename) [*c]const u8;
pub extern fn sqlite3_filename_wal(sqlite3_filename) [*c]const u8;
pub extern fn sqlite3_database_file_object([*c]const u8) [*c]sqlite3_file;
pub extern fn sqlite3_create_filename(zDatabase: [*c]const u8, zJournal: [*c]const u8, zWal: [*c]const u8, nParam: c_int, azParam: [*c][*c]const u8) sqlite3_filename;
pub extern fn sqlite3_free_filename(sqlite3_filename) void;
pub extern fn sqlite3_errcode(db: ?*sqlite3) c_int;
pub extern fn sqlite3_extended_errcode(db: ?*sqlite3) c_int;
pub extern fn sqlite3_errmsg(?*sqlite3) [*c]const u8;
pub extern fn sqlite3_errmsg16(?*sqlite3) ?*const anyopaque;
pub extern fn sqlite3_errstr(c_int) [*c]const u8;
pub extern fn sqlite3_error_offset(db: ?*sqlite3) c_int;
pub const struct_sqlite3_stmt = opaque {
    pub const sqlite3_sql = __root.sqlite3_sql;
    pub const sqlite3_expanded_sql = __root.sqlite3_expanded_sql;
    pub const sqlite3_stmt_readonly = __root.sqlite3_stmt_readonly;
    pub const sqlite3_stmt_isexplain = __root.sqlite3_stmt_isexplain;
    pub const sqlite3_stmt_explain = __root.sqlite3_stmt_explain;
    pub const sqlite3_stmt_busy = __root.sqlite3_stmt_busy;
    pub const sqlite3_bind_blob = __root.sqlite3_bind_blob;
    pub const sqlite3_bind_blob64 = __root.sqlite3_bind_blob64;
    pub const sqlite3_bind_double = __root.sqlite3_bind_double;
    pub const sqlite3_bind_int = __root.sqlite3_bind_int;
    pub const sqlite3_bind_int64 = __root.sqlite3_bind_int64;
    pub const sqlite3_bind_null = __root.sqlite3_bind_null;
    pub const sqlite3_bind_text = __root.sqlite3_bind_text;
    pub const sqlite3_bind_text16 = __root.sqlite3_bind_text16;
    pub const sqlite3_bind_text64 = __root.sqlite3_bind_text64;
    pub const sqlite3_bind_value = __root.sqlite3_bind_value;
    pub const sqlite3_bind_pointer = __root.sqlite3_bind_pointer;
    pub const sqlite3_bind_zeroblob = __root.sqlite3_bind_zeroblob;
    pub const sqlite3_bind_zeroblob64 = __root.sqlite3_bind_zeroblob64;
    pub const sqlite3_bind_parameter_count = __root.sqlite3_bind_parameter_count;
    pub const sqlite3_bind_parameter_name = __root.sqlite3_bind_parameter_name;
    pub const sqlite3_bind_parameter_index = __root.sqlite3_bind_parameter_index;
    pub const sqlite3_clear_bindings = __root.sqlite3_clear_bindings;
    pub const sqlite3_column_count = __root.sqlite3_column_count;
    pub const sqlite3_column_name = __root.sqlite3_column_name;
    pub const sqlite3_column_name16 = __root.sqlite3_column_name16;
    pub const sqlite3_column_database_name = __root.sqlite3_column_database_name;
    pub const sqlite3_column_database_name16 = __root.sqlite3_column_database_name16;
    pub const sqlite3_column_table_name = __root.sqlite3_column_table_name;
    pub const sqlite3_column_table_name16 = __root.sqlite3_column_table_name16;
    pub const sqlite3_column_origin_name = __root.sqlite3_column_origin_name;
    pub const sqlite3_column_origin_name16 = __root.sqlite3_column_origin_name16;
    pub const sqlite3_column_decltype = __root.sqlite3_column_decltype;
    pub const sqlite3_column_decltype16 = __root.sqlite3_column_decltype16;
    pub const sqlite3_step = __root.sqlite3_step;
    pub const sqlite3_data_count = __root.sqlite3_data_count;
    pub const sqlite3_column_blob = __root.sqlite3_column_blob;
    pub const sqlite3_column_double = __root.sqlite3_column_double;
    pub const sqlite3_column_int = __root.sqlite3_column_int;
    pub const sqlite3_column_int64 = __root.sqlite3_column_int64;
    pub const sqlite3_column_text = __root.sqlite3_column_text;
    pub const sqlite3_column_text16 = __root.sqlite3_column_text16;
    pub const sqlite3_column_value = __root.sqlite3_column_value;
    pub const sqlite3_column_bytes = __root.sqlite3_column_bytes;
    pub const sqlite3_column_bytes16 = __root.sqlite3_column_bytes16;
    pub const sqlite3_column_type = __root.sqlite3_column_type;
    pub const sqlite3_finalize = __root.sqlite3_finalize;
    pub const sqlite3_reset = __root.sqlite3_reset;
    pub const sqlite3_expired = __root.sqlite3_expired;
    pub const sqlite3_transfer_bindings = __root.sqlite3_transfer_bindings;
    pub const sqlite3_db_handle = __root.sqlite3_db_handle;
    pub const sqlite3_stmt_status = __root.sqlite3_stmt_status;
    pub const sqlite3_stmt_scanstatus = __root.sqlite3_stmt_scanstatus;
    pub const sqlite3_stmt_scanstatus_v2 = __root.sqlite3_stmt_scanstatus_v2;
    pub const sqlite3_stmt_scanstatus_reset = __root.sqlite3_stmt_scanstatus_reset;
    pub const sql = __root.sqlite3_sql;
    pub const readonly = __root.sqlite3_stmt_readonly;
    pub const isexplain = __root.sqlite3_stmt_isexplain;
    pub const explain = __root.sqlite3_stmt_explain;
    pub const busy = __root.sqlite3_stmt_busy;
    pub const blob = __root.sqlite3_bind_blob;
    pub const blob64 = __root.sqlite3_bind_blob64;
    pub const double = __root.sqlite3_bind_double;
    pub const int = __root.sqlite3_bind_int;
    pub const int64 = __root.sqlite3_bind_int64;
    pub const @"null" = __root.sqlite3_bind_null;
    pub const text = __root.sqlite3_bind_text;
    pub const text16 = __root.sqlite3_bind_text16;
    pub const text64 = __root.sqlite3_bind_text64;
    pub const value = __root.sqlite3_bind_value;
    pub const pointer = __root.sqlite3_bind_pointer;
    pub const zeroblob = __root.sqlite3_bind_zeroblob;
    pub const zeroblob64 = __root.sqlite3_bind_zeroblob64;
    pub const count = __root.sqlite3_bind_parameter_count;
    pub const name = __root.sqlite3_bind_parameter_name;
    pub const index = __root.sqlite3_bind_parameter_index;
    pub const bindings = __root.sqlite3_clear_bindings;
    pub const name16 = __root.sqlite3_column_name16;
    pub const decltype = __root.sqlite3_column_decltype;
    pub const decltype16 = __root.sqlite3_column_decltype16;
    pub const step = __root.sqlite3_step;
    pub const bytes = __root.sqlite3_column_bytes;
    pub const bytes16 = __root.sqlite3_column_bytes16;
    pub const @"type" = __root.sqlite3_column_type;
    pub const finalize = __root.sqlite3_finalize;
    pub const reset = __root.sqlite3_reset;
    pub const expired = __root.sqlite3_expired;
    pub const handle = __root.sqlite3_db_handle;
    pub const status = __root.sqlite3_stmt_status;
    pub const scanstatus = __root.sqlite3_stmt_scanstatus;
    pub const v2 = __root.sqlite3_stmt_scanstatus_v2;
};
pub const sqlite3_stmt = struct_sqlite3_stmt;
pub extern fn sqlite3_limit(?*sqlite3, id: c_int, newVal: c_int) c_int;
pub extern fn sqlite3_prepare(db: ?*sqlite3, zSql: [*c]const u8, nByte: c_int, ppStmt: [*c]?*sqlite3_stmt, pzTail: [*c][*c]const u8) c_int;
pub extern fn sqlite3_prepare_v2(db: ?*sqlite3, zSql: [*c]const u8, nByte: c_int, ppStmt: [*c]?*sqlite3_stmt, pzTail: [*c][*c]const u8) c_int;
pub extern fn sqlite3_prepare_v3(db: ?*sqlite3, zSql: [*c]const u8, nByte: c_int, prepFlags: c_uint, ppStmt: [*c]?*sqlite3_stmt, pzTail: [*c][*c]const u8) c_int;
pub extern fn sqlite3_prepare16(db: ?*sqlite3, zSql: ?*const anyopaque, nByte: c_int, ppStmt: [*c]?*sqlite3_stmt, pzTail: [*c]?*const anyopaque) c_int;
pub extern fn sqlite3_prepare16_v2(db: ?*sqlite3, zSql: ?*const anyopaque, nByte: c_int, ppStmt: [*c]?*sqlite3_stmt, pzTail: [*c]?*const anyopaque) c_int;
pub extern fn sqlite3_prepare16_v3(db: ?*sqlite3, zSql: ?*const anyopaque, nByte: c_int, prepFlags: c_uint, ppStmt: [*c]?*sqlite3_stmt, pzTail: [*c]?*const anyopaque) c_int;
pub extern fn sqlite3_sql(pStmt: ?*sqlite3_stmt) [*c]const u8;
pub extern fn sqlite3_expanded_sql(pStmt: ?*sqlite3_stmt) [*c]u8;
pub extern fn sqlite3_stmt_readonly(pStmt: ?*sqlite3_stmt) c_int;
pub extern fn sqlite3_stmt_isexplain(pStmt: ?*sqlite3_stmt) c_int;
pub extern fn sqlite3_stmt_explain(pStmt: ?*sqlite3_stmt, eMode: c_int) c_int;
pub extern fn sqlite3_stmt_busy(?*sqlite3_stmt) c_int;
pub const struct_sqlite3_value = opaque {
    pub const sqlite3_value_blob = __root.sqlite3_value_blob;
    pub const sqlite3_value_double = __root.sqlite3_value_double;
    pub const sqlite3_value_int = __root.sqlite3_value_int;
    pub const sqlite3_value_int64 = __root.sqlite3_value_int64;
    pub const sqlite3_value_pointer = __root.sqlite3_value_pointer;
    pub const sqlite3_value_text = __root.sqlite3_value_text;
    pub const sqlite3_value_text16 = __root.sqlite3_value_text16;
    pub const sqlite3_value_text16le = __root.sqlite3_value_text16le;
    pub const sqlite3_value_text16be = __root.sqlite3_value_text16be;
    pub const sqlite3_value_bytes = __root.sqlite3_value_bytes;
    pub const sqlite3_value_bytes16 = __root.sqlite3_value_bytes16;
    pub const sqlite3_value_type = __root.sqlite3_value_type;
    pub const sqlite3_value_numeric_type = __root.sqlite3_value_numeric_type;
    pub const sqlite3_value_nochange = __root.sqlite3_value_nochange;
    pub const sqlite3_value_frombind = __root.sqlite3_value_frombind;
    pub const sqlite3_value_encoding = __root.sqlite3_value_encoding;
    pub const sqlite3_value_subtype = __root.sqlite3_value_subtype;
    pub const sqlite3_value_dup = __root.sqlite3_value_dup;
    pub const sqlite3_value_free = __root.sqlite3_value_free;
    pub const sqlite3_vtab_in_first = __root.sqlite3_vtab_in_first;
    pub const sqlite3_vtab_in_next = __root.sqlite3_vtab_in_next;
    pub const blob = __root.sqlite3_value_blob;
    pub const double = __root.sqlite3_value_double;
    pub const int = __root.sqlite3_value_int;
    pub const int64 = __root.sqlite3_value_int64;
    pub const pointer = __root.sqlite3_value_pointer;
    pub const text = __root.sqlite3_value_text;
    pub const text16 = __root.sqlite3_value_text16;
    pub const text16le = __root.sqlite3_value_text16le;
    pub const text16be = __root.sqlite3_value_text16be;
    pub const bytes = __root.sqlite3_value_bytes;
    pub const bytes16 = __root.sqlite3_value_bytes16;
    pub const @"type" = __root.sqlite3_value_type;
    pub const nochange = __root.sqlite3_value_nochange;
    pub const frombind = __root.sqlite3_value_frombind;
    pub const encoding = __root.sqlite3_value_encoding;
    pub const subtype = __root.sqlite3_value_subtype;
    pub const dup = __root.sqlite3_value_dup;
    pub const free = __root.sqlite3_value_free;
    pub const first = __root.sqlite3_vtab_in_first;
    pub const next = __root.sqlite3_vtab_in_next;
};
pub const sqlite3_value = struct_sqlite3_value;
pub const struct_sqlite3_context = opaque {
    pub const sqlite3_aggregate_count = __root.sqlite3_aggregate_count;
    pub const sqlite3_aggregate_context = __root.sqlite3_aggregate_context;
    pub const sqlite3_user_data = __root.sqlite3_user_data;
    pub const sqlite3_context_db_handle = __root.sqlite3_context_db_handle;
    pub const sqlite3_get_auxdata = __root.sqlite3_get_auxdata;
    pub const sqlite3_set_auxdata = __root.sqlite3_set_auxdata;
    pub const sqlite3_result_blob = __root.sqlite3_result_blob;
    pub const sqlite3_result_blob64 = __root.sqlite3_result_blob64;
    pub const sqlite3_result_double = __root.sqlite3_result_double;
    pub const sqlite3_result_error = __root.sqlite3_result_error;
    pub const sqlite3_result_error16 = __root.sqlite3_result_error16;
    pub const sqlite3_result_error_toobig = __root.sqlite3_result_error_toobig;
    pub const sqlite3_result_error_nomem = __root.sqlite3_result_error_nomem;
    pub const sqlite3_result_error_code = __root.sqlite3_result_error_code;
    pub const sqlite3_result_int = __root.sqlite3_result_int;
    pub const sqlite3_result_int64 = __root.sqlite3_result_int64;
    pub const sqlite3_result_null = __root.sqlite3_result_null;
    pub const sqlite3_result_text = __root.sqlite3_result_text;
    pub const sqlite3_result_text64 = __root.sqlite3_result_text64;
    pub const sqlite3_result_text16 = __root.sqlite3_result_text16;
    pub const sqlite3_result_text16le = __root.sqlite3_result_text16le;
    pub const sqlite3_result_text16be = __root.sqlite3_result_text16be;
    pub const sqlite3_result_value = __root.sqlite3_result_value;
    pub const sqlite3_result_pointer = __root.sqlite3_result_pointer;
    pub const sqlite3_result_zeroblob = __root.sqlite3_result_zeroblob;
    pub const sqlite3_result_zeroblob64 = __root.sqlite3_result_zeroblob64;
    pub const sqlite3_result_subtype = __root.sqlite3_result_subtype;
    pub const sqlite3_vtab_nochange = __root.sqlite3_vtab_nochange;
    pub const count = __root.sqlite3_aggregate_count;
    pub const context = __root.sqlite3_aggregate_context;
    pub const data = __root.sqlite3_user_data;
    pub const handle = __root.sqlite3_context_db_handle;
    pub const auxdata = __root.sqlite3_get_auxdata;
    pub const blob = __root.sqlite3_result_blob;
    pub const blob64 = __root.sqlite3_result_blob64;
    pub const double = __root.sqlite3_result_double;
    pub const @"error" = __root.sqlite3_result_error;
    pub const error16 = __root.sqlite3_result_error16;
    pub const toobig = __root.sqlite3_result_error_toobig;
    pub const nomem = __root.sqlite3_result_error_nomem;
    pub const code = __root.sqlite3_result_error_code;
    pub const int = __root.sqlite3_result_int;
    pub const int64 = __root.sqlite3_result_int64;
    pub const @"null" = __root.sqlite3_result_null;
    pub const text = __root.sqlite3_result_text;
    pub const text64 = __root.sqlite3_result_text64;
    pub const text16 = __root.sqlite3_result_text16;
    pub const text16le = __root.sqlite3_result_text16le;
    pub const text16be = __root.sqlite3_result_text16be;
    pub const value = __root.sqlite3_result_value;
    pub const pointer = __root.sqlite3_result_pointer;
    pub const zeroblob = __root.sqlite3_result_zeroblob;
    pub const zeroblob64 = __root.sqlite3_result_zeroblob64;
    pub const subtype = __root.sqlite3_result_subtype;
    pub const nochange = __root.sqlite3_vtab_nochange;
};
pub const sqlite3_context = struct_sqlite3_context;
pub extern fn sqlite3_bind_blob(?*sqlite3_stmt, c_int, ?*const anyopaque, n: c_int, ?*const fn (?*anyopaque) callconv(.c) void) c_int;
pub extern fn sqlite3_bind_blob64(?*sqlite3_stmt, c_int, ?*const anyopaque, sqlite3_uint64, ?*const fn (?*anyopaque) callconv(.c) void) c_int;
pub extern fn sqlite3_bind_double(?*sqlite3_stmt, c_int, f64) c_int;
pub extern fn sqlite3_bind_int(?*sqlite3_stmt, c_int, c_int) c_int;
pub extern fn sqlite3_bind_int64(?*sqlite3_stmt, c_int, sqlite3_int64) c_int;
pub extern fn sqlite3_bind_null(?*sqlite3_stmt, c_int) c_int;
pub extern fn sqlite3_bind_text(?*sqlite3_stmt, c_int, [*c]const u8, c_int, ?*const fn (?*anyopaque) callconv(.c) void) c_int;
pub extern fn sqlite3_bind_text16(?*sqlite3_stmt, c_int, ?*const anyopaque, c_int, ?*const fn (?*anyopaque) callconv(.c) void) c_int;
pub extern fn sqlite3_bind_text64(?*sqlite3_stmt, c_int, [*c]const u8, sqlite3_uint64, ?*const fn (?*anyopaque) callconv(.c) void, encoding: u8) c_int;
pub extern fn sqlite3_bind_value(?*sqlite3_stmt, c_int, ?*const sqlite3_value) c_int;
pub extern fn sqlite3_bind_pointer(?*sqlite3_stmt, c_int, ?*anyopaque, [*c]const u8, ?*const fn (?*anyopaque) callconv(.c) void) c_int;
pub extern fn sqlite3_bind_zeroblob(?*sqlite3_stmt, c_int, n: c_int) c_int;
pub extern fn sqlite3_bind_zeroblob64(?*sqlite3_stmt, c_int, sqlite3_uint64) c_int;
pub extern fn sqlite3_bind_parameter_count(?*sqlite3_stmt) c_int;
pub extern fn sqlite3_bind_parameter_name(?*sqlite3_stmt, c_int) [*c]const u8;
pub extern fn sqlite3_bind_parameter_index(?*sqlite3_stmt, zName: [*c]const u8) c_int;
pub extern fn sqlite3_clear_bindings(?*sqlite3_stmt) c_int;
pub extern fn sqlite3_column_count(pStmt: ?*sqlite3_stmt) c_int;
pub extern fn sqlite3_column_name(?*sqlite3_stmt, N: c_int) [*c]const u8;
pub extern fn sqlite3_column_name16(?*sqlite3_stmt, N: c_int) ?*const anyopaque;
pub extern fn sqlite3_column_database_name(?*sqlite3_stmt, c_int) [*c]const u8;
pub extern fn sqlite3_column_database_name16(?*sqlite3_stmt, c_int) ?*const anyopaque;
pub extern fn sqlite3_column_table_name(?*sqlite3_stmt, c_int) [*c]const u8;
pub extern fn sqlite3_column_table_name16(?*sqlite3_stmt, c_int) ?*const anyopaque;
pub extern fn sqlite3_column_origin_name(?*sqlite3_stmt, c_int) [*c]const u8;
pub extern fn sqlite3_column_origin_name16(?*sqlite3_stmt, c_int) ?*const anyopaque;
pub extern fn sqlite3_column_decltype(?*sqlite3_stmt, c_int) [*c]const u8;
pub extern fn sqlite3_column_decltype16(?*sqlite3_stmt, c_int) ?*const anyopaque;
pub extern fn sqlite3_step(?*sqlite3_stmt) c_int;
pub extern fn sqlite3_data_count(pStmt: ?*sqlite3_stmt) c_int;
pub extern fn sqlite3_column_blob(?*sqlite3_stmt, iCol: c_int) ?*const anyopaque;
pub extern fn sqlite3_column_double(?*sqlite3_stmt, iCol: c_int) f64;
pub extern fn sqlite3_column_int(?*sqlite3_stmt, iCol: c_int) c_int;
pub extern fn sqlite3_column_int64(?*sqlite3_stmt, iCol: c_int) sqlite3_int64;
pub extern fn sqlite3_column_text(?*sqlite3_stmt, iCol: c_int) [*c]const u8;
pub extern fn sqlite3_column_text16(?*sqlite3_stmt, iCol: c_int) ?*const anyopaque;
pub extern fn sqlite3_column_value(?*sqlite3_stmt, iCol: c_int) ?*sqlite3_value;
pub extern fn sqlite3_column_bytes(?*sqlite3_stmt, iCol: c_int) c_int;
pub extern fn sqlite3_column_bytes16(?*sqlite3_stmt, iCol: c_int) c_int;
pub extern fn sqlite3_column_type(?*sqlite3_stmt, iCol: c_int) c_int;
pub extern fn sqlite3_finalize(pStmt: ?*sqlite3_stmt) c_int;
pub extern fn sqlite3_reset(pStmt: ?*sqlite3_stmt) c_int;
pub extern fn sqlite3_create_function(db: ?*sqlite3, zFunctionName: [*c]const u8, nArg: c_int, eTextRep: c_int, pApp: ?*anyopaque, xFunc: ?*const fn (?*sqlite3_context, c_int, [*c]?*sqlite3_value) callconv(.c) void, xStep: ?*const fn (?*sqlite3_context, c_int, [*c]?*sqlite3_value) callconv(.c) void, xFinal: ?*const fn (?*sqlite3_context) callconv(.c) void) c_int;
pub extern fn sqlite3_create_function16(db: ?*sqlite3, zFunctionName: ?*const anyopaque, nArg: c_int, eTextRep: c_int, pApp: ?*anyopaque, xFunc: ?*const fn (?*sqlite3_context, c_int, [*c]?*sqlite3_value) callconv(.c) void, xStep: ?*const fn (?*sqlite3_context, c_int, [*c]?*sqlite3_value) callconv(.c) void, xFinal: ?*const fn (?*sqlite3_context) callconv(.c) void) c_int;
pub extern fn sqlite3_create_function_v2(db: ?*sqlite3, zFunctionName: [*c]const u8, nArg: c_int, eTextRep: c_int, pApp: ?*anyopaque, xFunc: ?*const fn (?*sqlite3_context, c_int, [*c]?*sqlite3_value) callconv(.c) void, xStep: ?*const fn (?*sqlite3_context, c_int, [*c]?*sqlite3_value) callconv(.c) void, xFinal: ?*const fn (?*sqlite3_context) callconv(.c) void, xDestroy: ?*const fn (?*anyopaque) callconv(.c) void) c_int;
pub extern fn sqlite3_create_window_function(db: ?*sqlite3, zFunctionName: [*c]const u8, nArg: c_int, eTextRep: c_int, pApp: ?*anyopaque, xStep: ?*const fn (?*sqlite3_context, c_int, [*c]?*sqlite3_value) callconv(.c) void, xFinal: ?*const fn (?*sqlite3_context) callconv(.c) void, xValue: ?*const fn (?*sqlite3_context) callconv(.c) void, xInverse: ?*const fn (?*sqlite3_context, c_int, [*c]?*sqlite3_value) callconv(.c) void, xDestroy: ?*const fn (?*anyopaque) callconv(.c) void) c_int;
pub extern fn sqlite3_aggregate_count(?*sqlite3_context) c_int;
pub extern fn sqlite3_expired(?*sqlite3_stmt) c_int;
pub extern fn sqlite3_transfer_bindings(?*sqlite3_stmt, ?*sqlite3_stmt) c_int;
pub extern fn sqlite3_global_recover() c_int;
pub extern fn sqlite3_thread_cleanup() void;
pub extern fn sqlite3_memory_alarm(?*const fn (?*anyopaque, sqlite3_int64, c_int) callconv(.c) void, ?*anyopaque, sqlite3_int64) c_int;
pub extern fn sqlite3_value_blob(?*sqlite3_value) ?*const anyopaque;
pub extern fn sqlite3_value_double(?*sqlite3_value) f64;
pub extern fn sqlite3_value_int(?*sqlite3_value) c_int;
pub extern fn sqlite3_value_int64(?*sqlite3_value) sqlite3_int64;
pub extern fn sqlite3_value_pointer(?*sqlite3_value, [*c]const u8) ?*anyopaque;
pub extern fn sqlite3_value_text(?*sqlite3_value) [*c]const u8;
pub extern fn sqlite3_value_text16(?*sqlite3_value) ?*const anyopaque;
pub extern fn sqlite3_value_text16le(?*sqlite3_value) ?*const anyopaque;
pub extern fn sqlite3_value_text16be(?*sqlite3_value) ?*const anyopaque;
pub extern fn sqlite3_value_bytes(?*sqlite3_value) c_int;
pub extern fn sqlite3_value_bytes16(?*sqlite3_value) c_int;
pub extern fn sqlite3_value_type(?*sqlite3_value) c_int;
pub extern fn sqlite3_value_numeric_type(?*sqlite3_value) c_int;
pub extern fn sqlite3_value_nochange(?*sqlite3_value) c_int;
pub extern fn sqlite3_value_frombind(?*sqlite3_value) c_int;
pub extern fn sqlite3_value_encoding(?*sqlite3_value) c_int;
pub extern fn sqlite3_value_subtype(?*sqlite3_value) c_uint;
pub extern fn sqlite3_value_dup(?*const sqlite3_value) ?*sqlite3_value;
pub extern fn sqlite3_value_free(?*sqlite3_value) void;
pub extern fn sqlite3_aggregate_context(?*sqlite3_context, nBytes: c_int) ?*anyopaque;
pub extern fn sqlite3_user_data(?*sqlite3_context) ?*anyopaque;
pub extern fn sqlite3_context_db_handle(?*sqlite3_context) ?*sqlite3;
pub extern fn sqlite3_get_auxdata(?*sqlite3_context, N: c_int) ?*anyopaque;
pub extern fn sqlite3_set_auxdata(?*sqlite3_context, N: c_int, ?*anyopaque, ?*const fn (?*anyopaque) callconv(.c) void) void;
pub extern fn sqlite3_get_clientdata(?*sqlite3, [*c]const u8) ?*anyopaque;
pub extern fn sqlite3_set_clientdata(?*sqlite3, [*c]const u8, ?*anyopaque, ?*const fn (?*anyopaque) callconv(.c) void) c_int;
pub const sqlite3_destructor_type = ?*const fn (?*anyopaque) callconv(.c) void;
pub extern fn sqlite3_result_blob(?*sqlite3_context, ?*const anyopaque, c_int, ?*const fn (?*anyopaque) callconv(.c) void) void;
pub extern fn sqlite3_result_blob64(?*sqlite3_context, ?*const anyopaque, sqlite3_uint64, ?*const fn (?*anyopaque) callconv(.c) void) void;
pub extern fn sqlite3_result_double(?*sqlite3_context, f64) void;
pub extern fn sqlite3_result_error(?*sqlite3_context, [*c]const u8, c_int) void;
pub extern fn sqlite3_result_error16(?*sqlite3_context, ?*const anyopaque, c_int) void;
pub extern fn sqlite3_result_error_toobig(?*sqlite3_context) void;
pub extern fn sqlite3_result_error_nomem(?*sqlite3_context) void;
pub extern fn sqlite3_result_error_code(?*sqlite3_context, c_int) void;
pub extern fn sqlite3_result_int(?*sqlite3_context, c_int) void;
pub extern fn sqlite3_result_int64(?*sqlite3_context, sqlite3_int64) void;
pub extern fn sqlite3_result_null(?*sqlite3_context) void;
pub extern fn sqlite3_result_text(?*sqlite3_context, [*c]const u8, c_int, ?*const fn (?*anyopaque) callconv(.c) void) void;
pub extern fn sqlite3_result_text64(?*sqlite3_context, [*c]const u8, sqlite3_uint64, ?*const fn (?*anyopaque) callconv(.c) void, encoding: u8) void;
pub extern fn sqlite3_result_text16(?*sqlite3_context, ?*const anyopaque, c_int, ?*const fn (?*anyopaque) callconv(.c) void) void;
pub extern fn sqlite3_result_text16le(?*sqlite3_context, ?*const anyopaque, c_int, ?*const fn (?*anyopaque) callconv(.c) void) void;
pub extern fn sqlite3_result_text16be(?*sqlite3_context, ?*const anyopaque, c_int, ?*const fn (?*anyopaque) callconv(.c) void) void;
pub extern fn sqlite3_result_value(?*sqlite3_context, ?*sqlite3_value) void;
pub extern fn sqlite3_result_pointer(?*sqlite3_context, ?*anyopaque, [*c]const u8, ?*const fn (?*anyopaque) callconv(.c) void) void;
pub extern fn sqlite3_result_zeroblob(?*sqlite3_context, n: c_int) void;
pub extern fn sqlite3_result_zeroblob64(?*sqlite3_context, n: sqlite3_uint64) c_int;
pub extern fn sqlite3_result_subtype(?*sqlite3_context, c_uint) void;
pub extern fn sqlite3_create_collation(?*sqlite3, zName: [*c]const u8, eTextRep: c_int, pArg: ?*anyopaque, xCompare: ?*const fn (?*anyopaque, c_int, ?*const anyopaque, c_int, ?*const anyopaque) callconv(.c) c_int) c_int;
pub extern fn sqlite3_create_collation_v2(?*sqlite3, zName: [*c]const u8, eTextRep: c_int, pArg: ?*anyopaque, xCompare: ?*const fn (?*anyopaque, c_int, ?*const anyopaque, c_int, ?*const anyopaque) callconv(.c) c_int, xDestroy: ?*const fn (?*anyopaque) callconv(.c) void) c_int;
pub extern fn sqlite3_create_collation16(?*sqlite3, zName: ?*const anyopaque, eTextRep: c_int, pArg: ?*anyopaque, xCompare: ?*const fn (?*anyopaque, c_int, ?*const anyopaque, c_int, ?*const anyopaque) callconv(.c) c_int) c_int;
pub extern fn sqlite3_collation_needed(?*sqlite3, ?*anyopaque, ?*const fn (?*anyopaque, ?*sqlite3, eTextRep: c_int, [*c]const u8) callconv(.c) void) c_int;
pub extern fn sqlite3_collation_needed16(?*sqlite3, ?*anyopaque, ?*const fn (?*anyopaque, ?*sqlite3, eTextRep: c_int, ?*const anyopaque) callconv(.c) void) c_int;
pub extern fn sqlite3_sleep(c_int) c_int;
pub extern var sqlite3_temp_directory: [*c]u8;
pub extern var sqlite3_data_directory: [*c]u8;
pub extern fn sqlite3_win32_set_directory(@"type": c_ulong, zValue: ?*anyopaque) c_int;
pub extern fn sqlite3_win32_set_directory8(@"type": c_ulong, zValue: [*c]const u8) c_int;
pub extern fn sqlite3_win32_set_directory16(@"type": c_ulong, zValue: ?*const anyopaque) c_int;
pub extern fn sqlite3_get_autocommit(?*sqlite3) c_int;
pub extern fn sqlite3_db_handle(?*sqlite3_stmt) ?*sqlite3;
pub extern fn sqlite3_db_name(db: ?*sqlite3, N: c_int) [*c]const u8;
pub extern fn sqlite3_db_filename(db: ?*sqlite3, zDbName: [*c]const u8) sqlite3_filename;
pub extern fn sqlite3_db_readonly(db: ?*sqlite3, zDbName: [*c]const u8) c_int;
pub extern fn sqlite3_txn_state(?*sqlite3, zSchema: [*c]const u8) c_int;
pub extern fn sqlite3_next_stmt(pDb: ?*sqlite3, pStmt: ?*sqlite3_stmt) ?*sqlite3_stmt;
pub extern fn sqlite3_commit_hook(?*sqlite3, ?*const fn (?*anyopaque) callconv(.c) c_int, ?*anyopaque) ?*anyopaque;
pub extern fn sqlite3_rollback_hook(?*sqlite3, ?*const fn (?*anyopaque) callconv(.c) void, ?*anyopaque) ?*anyopaque;
pub extern fn sqlite3_autovacuum_pages(db: ?*sqlite3, ?*const fn (?*anyopaque, [*c]const u8, c_uint, c_uint, c_uint) callconv(.c) c_uint, ?*anyopaque, ?*const fn (?*anyopaque) callconv(.c) void) c_int;
pub extern fn sqlite3_update_hook(?*sqlite3, ?*const fn (?*anyopaque, c_int, [*c]const u8, [*c]const u8, sqlite3_int64) callconv(.c) void, ?*anyopaque) ?*anyopaque;
pub extern fn sqlite3_enable_shared_cache(c_int) c_int;
pub extern fn sqlite3_release_memory(c_int) c_int;
pub extern fn sqlite3_db_release_memory(?*sqlite3) c_int;
pub extern fn sqlite3_soft_heap_limit64(N: sqlite3_int64) sqlite3_int64;
pub extern fn sqlite3_hard_heap_limit64(N: sqlite3_int64) sqlite3_int64;
pub extern fn sqlite3_soft_heap_limit(N: c_int) void;
pub extern fn sqlite3_table_column_metadata(db: ?*sqlite3, zDbName: [*c]const u8, zTableName: [*c]const u8, zColumnName: [*c]const u8, pzDataType: [*c][*c]const u8, pzCollSeq: [*c][*c]const u8, pNotNull: [*c]c_int, pPrimaryKey: [*c]c_int, pAutoinc: [*c]c_int) c_int;
pub extern fn sqlite3_load_extension(db: ?*sqlite3, zFile: [*c]const u8, zProc: [*c]const u8, pzErrMsg: [*c][*c]u8) c_int;
pub extern fn sqlite3_enable_load_extension(db: ?*sqlite3, onoff: c_int) c_int;
pub extern fn sqlite3_auto_extension(xEntryPoint: ?*const fn () callconv(.c) void) c_int;
pub extern fn sqlite3_cancel_auto_extension(xEntryPoint: ?*const fn () callconv(.c) void) c_int;
pub extern fn sqlite3_reset_auto_extension() void;
pub const struct_sqlite3_index_constraint_2 = extern struct {
    iColumn: c_int = 0,
    op: u8 = 0,
    usable: u8 = 0,
    iTermOffset: c_int = 0,
};
pub const struct_sqlite3_index_orderby_3 = extern struct {
    iColumn: c_int = 0,
    desc: u8 = 0,
};
pub const struct_sqlite3_index_constraint_usage_4 = extern struct {
    argvIndex: c_int = 0,
    omit: u8 = 0,
};
pub const struct_sqlite3_index_info = extern struct {
    nConstraint: c_int = 0,
    aConstraint: [*c]struct_sqlite3_index_constraint_2 = null,
    nOrderBy: c_int = 0,
    aOrderBy: [*c]struct_sqlite3_index_orderby_3 = null,
    aConstraintUsage: [*c]struct_sqlite3_index_constraint_usage_4 = null,
    idxNum: c_int = 0,
    idxStr: [*c]u8 = null,
    needToFreeIdxStr: c_int = 0,
    orderByConsumed: c_int = 0,
    estimatedCost: f64 = 0,
    estimatedRows: sqlite3_int64 = 0,
    idxFlags: c_int = 0,
    colUsed: sqlite3_uint64 = 0,
    pub const sqlite3_vtab_collation = __root.sqlite3_vtab_collation;
    pub const sqlite3_vtab_distinct = __root.sqlite3_vtab_distinct;
    pub const sqlite3_vtab_in = __root.sqlite3_vtab_in;
    pub const sqlite3_vtab_rhs_value = __root.sqlite3_vtab_rhs_value;
    pub const collation = __root.sqlite3_vtab_collation;
    pub const distinct = __root.sqlite3_vtab_distinct;
    pub const in = __root.sqlite3_vtab_in;
    pub const value = __root.sqlite3_vtab_rhs_value;
};
pub const sqlite3_index_info = struct_sqlite3_index_info;
pub const struct_sqlite3_vtab_cursor = extern struct {
    pVtab: [*c]sqlite3_vtab = null,
};
pub const sqlite3_vtab_cursor = struct_sqlite3_vtab_cursor;
pub const struct_sqlite3_module = extern struct {
    iVersion: c_int = 0,
    xCreate: ?*const fn (?*sqlite3, pAux: ?*anyopaque, argc: c_int, argv: [*c]const [*c]const u8, ppVTab: [*c][*c]sqlite3_vtab, [*c][*c]u8) callconv(.c) c_int = null,
    xConnect: ?*const fn (?*sqlite3, pAux: ?*anyopaque, argc: c_int, argv: [*c]const [*c]const u8, ppVTab: [*c][*c]sqlite3_vtab, [*c][*c]u8) callconv(.c) c_int = null,
    xBestIndex: ?*const fn (pVTab: [*c]sqlite3_vtab, [*c]sqlite3_index_info) callconv(.c) c_int = null,
    xDisconnect: ?*const fn (pVTab: [*c]sqlite3_vtab) callconv(.c) c_int = null,
    xDestroy: ?*const fn (pVTab: [*c]sqlite3_vtab) callconv(.c) c_int = null,
    xOpen: ?*const fn (pVTab: [*c]sqlite3_vtab, ppCursor: [*c][*c]sqlite3_vtab_cursor) callconv(.c) c_int = null,
    xClose: ?*const fn ([*c]sqlite3_vtab_cursor) callconv(.c) c_int = null,
    xFilter: ?*const fn ([*c]sqlite3_vtab_cursor, idxNum: c_int, idxStr: [*c]const u8, argc: c_int, argv: [*c]?*sqlite3_value) callconv(.c) c_int = null,
    xNext: ?*const fn ([*c]sqlite3_vtab_cursor) callconv(.c) c_int = null,
    xEof: ?*const fn ([*c]sqlite3_vtab_cursor) callconv(.c) c_int = null,
    xColumn: ?*const fn ([*c]sqlite3_vtab_cursor, ?*sqlite3_context, c_int) callconv(.c) c_int = null,
    xRowid: ?*const fn ([*c]sqlite3_vtab_cursor, pRowid: [*c]sqlite3_int64) callconv(.c) c_int = null,
    xUpdate: ?*const fn ([*c]sqlite3_vtab, c_int, [*c]?*sqlite3_value, [*c]sqlite3_int64) callconv(.c) c_int = null,
    xBegin: ?*const fn (pVTab: [*c]sqlite3_vtab) callconv(.c) c_int = null,
    xSync: ?*const fn (pVTab: [*c]sqlite3_vtab) callconv(.c) c_int = null,
    xCommit: ?*const fn (pVTab: [*c]sqlite3_vtab) callconv(.c) c_int = null,
    xRollback: ?*const fn (pVTab: [*c]sqlite3_vtab) callconv(.c) c_int = null,
    xFindFunction: ?*const fn (pVtab: [*c]sqlite3_vtab, nArg: c_int, zName: [*c]const u8, pxFunc: [*c]?*const fn (?*sqlite3_context, c_int, [*c]?*sqlite3_value) callconv(.c) void, ppArg: [*c]?*anyopaque) callconv(.c) c_int = null,
    xRename: ?*const fn (pVtab: [*c]sqlite3_vtab, zNew: [*c]const u8) callconv(.c) c_int = null,
    xSavepoint: ?*const fn (pVTab: [*c]sqlite3_vtab, c_int) callconv(.c) c_int = null,
    xRelease: ?*const fn (pVTab: [*c]sqlite3_vtab, c_int) callconv(.c) c_int = null,
    xRollbackTo: ?*const fn (pVTab: [*c]sqlite3_vtab, c_int) callconv(.c) c_int = null,
    xShadowName: ?*const fn ([*c]const u8) callconv(.c) c_int = null,
    xIntegrity: ?*const fn (pVTab: [*c]sqlite3_vtab, zSchema: [*c]const u8, zTabName: [*c]const u8, mFlags: c_int, pzErr: [*c][*c]u8) callconv(.c) c_int = null,
};
pub const sqlite3_module = struct_sqlite3_module;
pub const struct_sqlite3_vtab = extern struct {
    pModule: [*c]const sqlite3_module = null,
    nRef: c_int = 0,
    zErrMsg: [*c]u8 = null,
};
pub const sqlite3_vtab = struct_sqlite3_vtab;
pub extern fn sqlite3_create_module(db: ?*sqlite3, zName: [*c]const u8, p: [*c]const sqlite3_module, pClientData: ?*anyopaque) c_int;
pub extern fn sqlite3_create_module_v2(db: ?*sqlite3, zName: [*c]const u8, p: [*c]const sqlite3_module, pClientData: ?*anyopaque, xDestroy: ?*const fn (?*anyopaque) callconv(.c) void) c_int;
pub extern fn sqlite3_drop_modules(db: ?*sqlite3, azKeep: [*c][*c]const u8) c_int;
pub extern fn sqlite3_declare_vtab(?*sqlite3, zSQL: [*c]const u8) c_int;
pub extern fn sqlite3_overload_function(?*sqlite3, zFuncName: [*c]const u8, nArg: c_int) c_int;
pub const struct_sqlite3_blob = opaque {
    pub const sqlite3_blob_reopen = __root.sqlite3_blob_reopen;
    pub const sqlite3_blob_close = __root.sqlite3_blob_close;
    pub const sqlite3_blob_bytes = __root.sqlite3_blob_bytes;
    pub const sqlite3_blob_read = __root.sqlite3_blob_read;
    pub const sqlite3_blob_write = __root.sqlite3_blob_write;
    pub const reopen = __root.sqlite3_blob_reopen;
    pub const close = __root.sqlite3_blob_close;
    pub const bytes = __root.sqlite3_blob_bytes;
    pub const read = __root.sqlite3_blob_read;
    pub const write = __root.sqlite3_blob_write;
};
pub const sqlite3_blob = struct_sqlite3_blob;
pub extern fn sqlite3_blob_open(?*sqlite3, zDb: [*c]const u8, zTable: [*c]const u8, zColumn: [*c]const u8, iRow: sqlite3_int64, flags: c_int, ppBlob: [*c]?*sqlite3_blob) c_int;
pub extern fn sqlite3_blob_reopen(?*sqlite3_blob, sqlite3_int64) c_int;
pub extern fn sqlite3_blob_close(?*sqlite3_blob) c_int;
pub extern fn sqlite3_blob_bytes(?*sqlite3_blob) c_int;
pub extern fn sqlite3_blob_read(?*sqlite3_blob, Z: ?*anyopaque, N: c_int, iOffset: c_int) c_int;
pub extern fn sqlite3_blob_write(?*sqlite3_blob, z: ?*const anyopaque, n: c_int, iOffset: c_int) c_int;
pub extern fn sqlite3_vfs_find(zVfsName: [*c]const u8) [*c]sqlite3_vfs;
pub extern fn sqlite3_vfs_register([*c]sqlite3_vfs, makeDflt: c_int) c_int;
pub extern fn sqlite3_vfs_unregister([*c]sqlite3_vfs) c_int;
pub extern fn sqlite3_mutex_alloc(c_int) ?*sqlite3_mutex;
pub extern fn sqlite3_mutex_free(?*sqlite3_mutex) void;
pub extern fn sqlite3_mutex_enter(?*sqlite3_mutex) void;
pub extern fn sqlite3_mutex_try(?*sqlite3_mutex) c_int;
pub extern fn sqlite3_mutex_leave(?*sqlite3_mutex) void;
pub const struct_sqlite3_mutex_methods = extern struct {
    xMutexInit: ?*const fn () callconv(.c) c_int = null,
    xMutexEnd: ?*const fn () callconv(.c) c_int = null,
    xMutexAlloc: ?*const fn (c_int) callconv(.c) ?*sqlite3_mutex = null,
    xMutexFree: ?*const fn (?*sqlite3_mutex) callconv(.c) void = null,
    xMutexEnter: ?*const fn (?*sqlite3_mutex) callconv(.c) void = null,
    xMutexTry: ?*const fn (?*sqlite3_mutex) callconv(.c) c_int = null,
    xMutexLeave: ?*const fn (?*sqlite3_mutex) callconv(.c) void = null,
    xMutexHeld: ?*const fn (?*sqlite3_mutex) callconv(.c) c_int = null,
    xMutexNotheld: ?*const fn (?*sqlite3_mutex) callconv(.c) c_int = null,
};
pub const sqlite3_mutex_methods = struct_sqlite3_mutex_methods;
pub extern fn sqlite3_mutex_held(?*sqlite3_mutex) c_int;
pub extern fn sqlite3_mutex_notheld(?*sqlite3_mutex) c_int;
pub extern fn sqlite3_db_mutex(?*sqlite3) ?*sqlite3_mutex;
pub extern fn sqlite3_file_control(?*sqlite3, zDbName: [*c]const u8, op: c_int, ?*anyopaque) c_int;
pub extern fn sqlite3_test_control(op: c_int, ...) c_int;
pub extern fn sqlite3_keyword_count() c_int;
pub extern fn sqlite3_keyword_name(c_int, [*c][*c]const u8, [*c]c_int) c_int;
pub extern fn sqlite3_keyword_check([*c]const u8, c_int) c_int;
pub const struct_sqlite3_str = opaque {
    pub const sqlite3_str_finish = __root.sqlite3_str_finish;
    pub const sqlite3_str_appendf = __root.sqlite3_str_appendf;
    pub const sqlite3_str_vappendf = __root.sqlite3_str_vappendf;
    pub const sqlite3_str_append = __root.sqlite3_str_append;
    pub const sqlite3_str_appendall = __root.sqlite3_str_appendall;
    pub const sqlite3_str_appendchar = __root.sqlite3_str_appendchar;
    pub const sqlite3_str_reset = __root.sqlite3_str_reset;
    pub const sqlite3_str_errcode = __root.sqlite3_str_errcode;
    pub const sqlite3_str_length = __root.sqlite3_str_length;
    pub const sqlite3_str_value = __root.sqlite3_str_value;
    pub const finish = __root.sqlite3_str_finish;
    pub const appendf = __root.sqlite3_str_appendf;
    pub const vappendf = __root.sqlite3_str_vappendf;
    pub const append = __root.sqlite3_str_append;
    pub const appendall = __root.sqlite3_str_appendall;
    pub const appendchar = __root.sqlite3_str_appendchar;
    pub const reset = __root.sqlite3_str_reset;
    pub const errcode = __root.sqlite3_str_errcode;
    pub const length = __root.sqlite3_str_length;
    pub const value = __root.sqlite3_str_value;
};
pub const sqlite3_str = struct_sqlite3_str;
pub extern fn sqlite3_str_new(?*sqlite3) ?*sqlite3_str;
pub extern fn sqlite3_str_finish(?*sqlite3_str) [*c]u8;
pub extern fn sqlite3_str_appendf(?*sqlite3_str, zFormat: [*c]const u8, ...) void;
pub extern fn sqlite3_str_vappendf(?*sqlite3_str, zFormat: [*c]const u8, [*c]struct___va_list_tag_1) void;
pub extern fn sqlite3_str_append(?*sqlite3_str, zIn: [*c]const u8, N: c_int) void;
pub extern fn sqlite3_str_appendall(?*sqlite3_str, zIn: [*c]const u8) void;
pub extern fn sqlite3_str_appendchar(?*sqlite3_str, N: c_int, C: u8) void;
pub extern fn sqlite3_str_reset(?*sqlite3_str) void;
pub extern fn sqlite3_str_errcode(?*sqlite3_str) c_int;
pub extern fn sqlite3_str_length(?*sqlite3_str) c_int;
pub extern fn sqlite3_str_value(?*sqlite3_str) [*c]u8;
pub extern fn sqlite3_status(op: c_int, pCurrent: [*c]c_int, pHighwater: [*c]c_int, resetFlag: c_int) c_int;
pub extern fn sqlite3_status64(op: c_int, pCurrent: [*c]sqlite3_int64, pHighwater: [*c]sqlite3_int64, resetFlag: c_int) c_int;
pub extern fn sqlite3_db_status(?*sqlite3, op: c_int, pCur: [*c]c_int, pHiwtr: [*c]c_int, resetFlg: c_int) c_int;
pub extern fn sqlite3_stmt_status(?*sqlite3_stmt, op: c_int, resetFlg: c_int) c_int;
pub const struct_sqlite3_pcache = opaque {};
pub const sqlite3_pcache = struct_sqlite3_pcache;
pub const struct_sqlite3_pcache_page = extern struct {
    pBuf: ?*anyopaque = null,
    pExtra: ?*anyopaque = null,
};
pub const sqlite3_pcache_page = struct_sqlite3_pcache_page;
pub const struct_sqlite3_pcache_methods2 = extern struct {
    iVersion: c_int = 0,
    pArg: ?*anyopaque = null,
    xInit: ?*const fn (?*anyopaque) callconv(.c) c_int = null,
    xShutdown: ?*const fn (?*anyopaque) callconv(.c) void = null,
    xCreate: ?*const fn (szPage: c_int, szExtra: c_int, bPurgeable: c_int) callconv(.c) ?*sqlite3_pcache = null,
    xCachesize: ?*const fn (?*sqlite3_pcache, nCachesize: c_int) callconv(.c) void = null,
    xPagecount: ?*const fn (?*sqlite3_pcache) callconv(.c) c_int = null,
    xFetch: ?*const fn (?*sqlite3_pcache, key: c_uint, createFlag: c_int) callconv(.c) [*c]sqlite3_pcache_page = null,
    xUnpin: ?*const fn (?*sqlite3_pcache, [*c]sqlite3_pcache_page, discard: c_int) callconv(.c) void = null,
    xRekey: ?*const fn (?*sqlite3_pcache, [*c]sqlite3_pcache_page, oldKey: c_uint, newKey: c_uint) callconv(.c) void = null,
    xTruncate: ?*const fn (?*sqlite3_pcache, iLimit: c_uint) callconv(.c) void = null,
    xDestroy: ?*const fn (?*sqlite3_pcache) callconv(.c) void = null,
    xShrink: ?*const fn (?*sqlite3_pcache) callconv(.c) void = null,
};
pub const sqlite3_pcache_methods2 = struct_sqlite3_pcache_methods2;
pub const struct_sqlite3_pcache_methods = extern struct {
    pArg: ?*anyopaque = null,
    xInit: ?*const fn (?*anyopaque) callconv(.c) c_int = null,
    xShutdown: ?*const fn (?*anyopaque) callconv(.c) void = null,
    xCreate: ?*const fn (szPage: c_int, bPurgeable: c_int) callconv(.c) ?*sqlite3_pcache = null,
    xCachesize: ?*const fn (?*sqlite3_pcache, nCachesize: c_int) callconv(.c) void = null,
    xPagecount: ?*const fn (?*sqlite3_pcache) callconv(.c) c_int = null,
    xFetch: ?*const fn (?*sqlite3_pcache, key: c_uint, createFlag: c_int) callconv(.c) ?*anyopaque = null,
    xUnpin: ?*const fn (?*sqlite3_pcache, ?*anyopaque, discard: c_int) callconv(.c) void = null,
    xRekey: ?*const fn (?*sqlite3_pcache, ?*anyopaque, oldKey: c_uint, newKey: c_uint) callconv(.c) void = null,
    xTruncate: ?*const fn (?*sqlite3_pcache, iLimit: c_uint) callconv(.c) void = null,
    xDestroy: ?*const fn (?*sqlite3_pcache) callconv(.c) void = null,
};
pub const sqlite3_pcache_methods = struct_sqlite3_pcache_methods;
pub const struct_sqlite3_backup = opaque {
    pub const sqlite3_backup_step = __root.sqlite3_backup_step;
    pub const sqlite3_backup_finish = __root.sqlite3_backup_finish;
    pub const sqlite3_backup_remaining = __root.sqlite3_backup_remaining;
    pub const sqlite3_backup_pagecount = __root.sqlite3_backup_pagecount;
    pub const step = __root.sqlite3_backup_step;
    pub const finish = __root.sqlite3_backup_finish;
    pub const remaining = __root.sqlite3_backup_remaining;
    pub const pagecount = __root.sqlite3_backup_pagecount;
};
pub const sqlite3_backup = struct_sqlite3_backup;
pub extern fn sqlite3_backup_init(pDest: ?*sqlite3, zDestName: [*c]const u8, pSource: ?*sqlite3, zSourceName: [*c]const u8) ?*sqlite3_backup;
pub extern fn sqlite3_backup_step(p: ?*sqlite3_backup, nPage: c_int) c_int;
pub extern fn sqlite3_backup_finish(p: ?*sqlite3_backup) c_int;
pub extern fn sqlite3_backup_remaining(p: ?*sqlite3_backup) c_int;
pub extern fn sqlite3_backup_pagecount(p: ?*sqlite3_backup) c_int;
pub extern fn sqlite3_unlock_notify(pBlocked: ?*sqlite3, xNotify: ?*const fn (apArg: [*c]?*anyopaque, nArg: c_int) callconv(.c) void, pNotifyArg: ?*anyopaque) c_int;
pub extern fn sqlite3_stricmp([*c]const u8, [*c]const u8) c_int;
pub extern fn sqlite3_strnicmp([*c]const u8, [*c]const u8, c_int) c_int;
pub extern fn sqlite3_strglob(zGlob: [*c]const u8, zStr: [*c]const u8) c_int;
pub extern fn sqlite3_strlike(zGlob: [*c]const u8, zStr: [*c]const u8, cEsc: c_uint) c_int;
pub extern fn sqlite3_log(iErrCode: c_int, zFormat: [*c]const u8, ...) void;
pub extern fn sqlite3_wal_hook(?*sqlite3, ?*const fn (?*anyopaque, ?*sqlite3, [*c]const u8, c_int) callconv(.c) c_int, ?*anyopaque) ?*anyopaque;
pub extern fn sqlite3_wal_autocheckpoint(db: ?*sqlite3, N: c_int) c_int;
pub extern fn sqlite3_wal_checkpoint(db: ?*sqlite3, zDb: [*c]const u8) c_int;
pub extern fn sqlite3_wal_checkpoint_v2(db: ?*sqlite3, zDb: [*c]const u8, eMode: c_int, pnLog: [*c]c_int, pnCkpt: [*c]c_int) c_int;
pub extern fn sqlite3_vtab_config(?*sqlite3, op: c_int, ...) c_int;
pub extern fn sqlite3_vtab_on_conflict(?*sqlite3) c_int;
pub extern fn sqlite3_vtab_nochange(?*sqlite3_context) c_int;
pub extern fn sqlite3_vtab_collation([*c]sqlite3_index_info, c_int) [*c]const u8;
pub extern fn sqlite3_vtab_distinct([*c]sqlite3_index_info) c_int;
pub extern fn sqlite3_vtab_in([*c]sqlite3_index_info, iCons: c_int, bHandle: c_int) c_int;
pub extern fn sqlite3_vtab_in_first(pVal: ?*sqlite3_value, ppOut: [*c]?*sqlite3_value) c_int;
pub extern fn sqlite3_vtab_in_next(pVal: ?*sqlite3_value, ppOut: [*c]?*sqlite3_value) c_int;
pub extern fn sqlite3_vtab_rhs_value([*c]sqlite3_index_info, c_int, ppVal: [*c]?*sqlite3_value) c_int;
pub extern fn sqlite3_stmt_scanstatus(pStmt: ?*sqlite3_stmt, idx: c_int, iScanStatusOp: c_int, pOut: ?*anyopaque) c_int;
pub extern fn sqlite3_stmt_scanstatus_v2(pStmt: ?*sqlite3_stmt, idx: c_int, iScanStatusOp: c_int, flags: c_int, pOut: ?*anyopaque) c_int;
pub extern fn sqlite3_stmt_scanstatus_reset(?*sqlite3_stmt) void;
pub extern fn sqlite3_db_cacheflush(?*sqlite3) c_int;
pub extern fn sqlite3_system_errno(?*sqlite3) c_int;
pub const struct_sqlite3_snapshot = extern struct {
    hidden: [48]u8 = @import("std").mem.zeroes([48]u8),
    pub const sqlite3_snapshot_free = __root.sqlite3_snapshot_free;
    pub const sqlite3_snapshot_cmp = __root.sqlite3_snapshot_cmp;
    pub const free = __root.sqlite3_snapshot_free;
    pub const cmp = __root.sqlite3_snapshot_cmp;
};
pub const sqlite3_snapshot = struct_sqlite3_snapshot;
pub extern fn sqlite3_snapshot_get(db: ?*sqlite3, zSchema: [*c]const u8, ppSnapshot: [*c][*c]sqlite3_snapshot) c_int;
pub extern fn sqlite3_snapshot_open(db: ?*sqlite3, zSchema: [*c]const u8, pSnapshot: [*c]sqlite3_snapshot) c_int;
pub extern fn sqlite3_snapshot_free([*c]sqlite3_snapshot) void;
pub extern fn sqlite3_snapshot_cmp(p1: [*c]sqlite3_snapshot, p2: [*c]sqlite3_snapshot) c_int;
pub extern fn sqlite3_snapshot_recover(db: ?*sqlite3, zDb: [*c]const u8) c_int;
pub extern fn sqlite3_serialize(db: ?*sqlite3, zSchema: [*c]const u8, piSize: [*c]sqlite3_int64, mFlags: c_uint) [*c]u8;
pub extern fn sqlite3_deserialize(db: ?*sqlite3, zSchema: [*c]const u8, pData: [*c]u8, szDb: sqlite3_int64, szBuf: sqlite3_int64, mFlags: c_uint) c_int;
pub const sqlite3_rtree_dbl = f64;
pub const struct_sqlite3_rtree_geometry = extern struct {
    pContext: ?*anyopaque = null,
    nParam: c_int = 0,
    aParam: [*c]sqlite3_rtree_dbl = null,
    pUser: ?*anyopaque = null,
    xDelUser: ?*const fn (?*anyopaque) callconv(.c) void = null,
};
pub const sqlite3_rtree_geometry = struct_sqlite3_rtree_geometry;
pub const struct_sqlite3_rtree_query_info = extern struct {
    pContext: ?*anyopaque = null,
    nParam: c_int = 0,
    aParam: [*c]sqlite3_rtree_dbl = null,
    pUser: ?*anyopaque = null,
    xDelUser: ?*const fn (?*anyopaque) callconv(.c) void = null,
    aCoord: [*c]sqlite3_rtree_dbl = null,
    anQueue: [*c]c_uint = null,
    nCoord: c_int = 0,
    iLevel: c_int = 0,
    mxLevel: c_int = 0,
    iRowid: sqlite3_int64 = 0,
    rParentScore: sqlite3_rtree_dbl = 0,
    eParentWithin: c_int = 0,
    eWithin: c_int = 0,
    rScore: sqlite3_rtree_dbl = 0,
    apSqlParam: [*c]?*sqlite3_value = null,
};
pub const sqlite3_rtree_query_info = struct_sqlite3_rtree_query_info;
pub extern fn sqlite3_rtree_geometry_callback(db: ?*sqlite3, zGeom: [*c]const u8, xGeom: ?*const fn ([*c]sqlite3_rtree_geometry, c_int, [*c]sqlite3_rtree_dbl, [*c]c_int) callconv(.c) c_int, pContext: ?*anyopaque) c_int;
pub extern fn sqlite3_rtree_query_callback(db: ?*sqlite3, zQueryFunc: [*c]const u8, xQueryFunc: ?*const fn ([*c]sqlite3_rtree_query_info) callconv(.c) c_int, pContext: ?*anyopaque, xDestructor: ?*const fn (?*anyopaque) callconv(.c) void) c_int;
pub const struct_Fts5Context = opaque {};
pub const Fts5Context = struct_Fts5Context;
pub const struct_Fts5PhraseIter = extern struct {
    a: [*c]const u8 = null,
    b: [*c]const u8 = null,
};
pub const Fts5PhraseIter = struct_Fts5PhraseIter;
pub const struct_Fts5ExtensionApi = extern struct {
    iVersion: c_int = 0,
    xUserData: ?*const fn (?*Fts5Context) callconv(.c) ?*anyopaque = null,
    xColumnCount: ?*const fn (?*Fts5Context) callconv(.c) c_int = null,
    xRowCount: ?*const fn (?*Fts5Context, pnRow: [*c]sqlite3_int64) callconv(.c) c_int = null,
    xColumnTotalSize: ?*const fn (?*Fts5Context, iCol: c_int, pnToken: [*c]sqlite3_int64) callconv(.c) c_int = null,
    xTokenize: ?*const fn (?*Fts5Context, pText: [*c]const u8, nText: c_int, pCtx: ?*anyopaque, xToken: ?*const fn (?*anyopaque, c_int, [*c]const u8, c_int, c_int, c_int) callconv(.c) c_int) callconv(.c) c_int = null,
    xPhraseCount: ?*const fn (?*Fts5Context) callconv(.c) c_int = null,
    xPhraseSize: ?*const fn (?*Fts5Context, iPhrase: c_int) callconv(.c) c_int = null,
    xInstCount: ?*const fn (?*Fts5Context, pnInst: [*c]c_int) callconv(.c) c_int = null,
    xInst: ?*const fn (?*Fts5Context, iIdx: c_int, piPhrase: [*c]c_int, piCol: [*c]c_int, piOff: [*c]c_int) callconv(.c) c_int = null,
    xRowid: ?*const fn (?*Fts5Context) callconv(.c) sqlite3_int64 = null,
    xColumnText: ?*const fn (?*Fts5Context, iCol: c_int, pz: [*c][*c]const u8, pn: [*c]c_int) callconv(.c) c_int = null,
    xColumnSize: ?*const fn (?*Fts5Context, iCol: c_int, pnToken: [*c]c_int) callconv(.c) c_int = null,
    xQueryPhrase: ?*const fn (?*Fts5Context, iPhrase: c_int, pUserData: ?*anyopaque, ?*const fn ([*c]const Fts5ExtensionApi, ?*Fts5Context, ?*anyopaque) callconv(.c) c_int) callconv(.c) c_int = null,
    xSetAuxdata: ?*const fn (?*Fts5Context, pAux: ?*anyopaque, xDelete: ?*const fn (?*anyopaque) callconv(.c) void) callconv(.c) c_int = null,
    xGetAuxdata: ?*const fn (?*Fts5Context, bClear: c_int) callconv(.c) ?*anyopaque = null,
    xPhraseFirst: ?*const fn (?*Fts5Context, iPhrase: c_int, [*c]Fts5PhraseIter, [*c]c_int, [*c]c_int) callconv(.c) c_int = null,
    xPhraseNext: ?*const fn (?*Fts5Context, [*c]Fts5PhraseIter, piCol: [*c]c_int, piOff: [*c]c_int) callconv(.c) void = null,
    xPhraseFirstColumn: ?*const fn (?*Fts5Context, iPhrase: c_int, [*c]Fts5PhraseIter, [*c]c_int) callconv(.c) c_int = null,
    xPhraseNextColumn: ?*const fn (?*Fts5Context, [*c]Fts5PhraseIter, piCol: [*c]c_int) callconv(.c) void = null,
    xQueryToken: ?*const fn (?*Fts5Context, iPhrase: c_int, iToken: c_int, ppToken: [*c][*c]const u8, pnToken: [*c]c_int) callconv(.c) c_int = null,
    xInstToken: ?*const fn (?*Fts5Context, iIdx: c_int, iToken: c_int, [*c][*c]const u8, [*c]c_int) callconv(.c) c_int = null,
    xColumnLocale: ?*const fn (?*Fts5Context, iCol: c_int, pz: [*c][*c]const u8, pn: [*c]c_int) callconv(.c) c_int = null,
    xTokenize_v2: ?*const fn (?*Fts5Context, pText: [*c]const u8, nText: c_int, pLocale: [*c]const u8, nLocale: c_int, pCtx: ?*anyopaque, xToken: ?*const fn (?*anyopaque, c_int, [*c]const u8, c_int, c_int, c_int) callconv(.c) c_int) callconv(.c) c_int = null,
};
pub const Fts5ExtensionApi = struct_Fts5ExtensionApi;
pub const fts5_extension_function = ?*const fn (pApi: [*c]const Fts5ExtensionApi, pFts: ?*Fts5Context, pCtx: ?*sqlite3_context, nVal: c_int, apVal: [*c]?*sqlite3_value) callconv(.c) void;
pub const struct_Fts5Tokenizer = opaque {};
pub const Fts5Tokenizer = struct_Fts5Tokenizer;
pub const struct_fts5_tokenizer_v2 = extern struct {
    iVersion: c_int = 0,
    xCreate: ?*const fn (?*anyopaque, azArg: [*c][*c]const u8, nArg: c_int, ppOut: [*c]?*Fts5Tokenizer) callconv(.c) c_int = null,
    xDelete: ?*const fn (?*Fts5Tokenizer) callconv(.c) void = null,
    xTokenize: ?*const fn (?*Fts5Tokenizer, pCtx: ?*anyopaque, flags: c_int, pText: [*c]const u8, nText: c_int, pLocale: [*c]const u8, nLocale: c_int, xToken: ?*const fn (pCtx: ?*anyopaque, tflags: c_int, pToken: [*c]const u8, nToken: c_int, iStart: c_int, iEnd: c_int) callconv(.c) c_int) callconv(.c) c_int = null,
};
pub const fts5_tokenizer_v2 = struct_fts5_tokenizer_v2;
pub const struct_fts5_tokenizer = extern struct {
    xCreate: ?*const fn (?*anyopaque, azArg: [*c][*c]const u8, nArg: c_int, ppOut: [*c]?*Fts5Tokenizer) callconv(.c) c_int = null,
    xDelete: ?*const fn (?*Fts5Tokenizer) callconv(.c) void = null,
    xTokenize: ?*const fn (?*Fts5Tokenizer, pCtx: ?*anyopaque, flags: c_int, pText: [*c]const u8, nText: c_int, xToken: ?*const fn (pCtx: ?*anyopaque, tflags: c_int, pToken: [*c]const u8, nToken: c_int, iStart: c_int, iEnd: c_int) callconv(.c) c_int) callconv(.c) c_int = null,
};
pub const fts5_tokenizer = struct_fts5_tokenizer;
pub const struct_fts5_api = extern struct {
    iVersion: c_int = 0,
    xCreateTokenizer: ?*const fn (pApi: [*c]fts5_api, zName: [*c]const u8, pUserData: ?*anyopaque, pTokenizer: [*c]fts5_tokenizer, xDestroy: ?*const fn (?*anyopaque) callconv(.c) void) callconv(.c) c_int = null,
    xFindTokenizer: ?*const fn (pApi: [*c]fts5_api, zName: [*c]const u8, ppUserData: [*c]?*anyopaque, pTokenizer: [*c]fts5_tokenizer) callconv(.c) c_int = null,
    xCreateFunction: ?*const fn (pApi: [*c]fts5_api, zName: [*c]const u8, pUserData: ?*anyopaque, xFunction: fts5_extension_function, xDestroy: ?*const fn (?*anyopaque) callconv(.c) void) callconv(.c) c_int = null,
    xCreateTokenizer_v2: ?*const fn (pApi: [*c]fts5_api, zName: [*c]const u8, pUserData: ?*anyopaque, pTokenizer: [*c]fts5_tokenizer_v2, xDestroy: ?*const fn (?*anyopaque) callconv(.c) void) callconv(.c) c_int = null,
    xFindTokenizer_v2: ?*const fn (pApi: [*c]fts5_api, zName: [*c]const u8, ppUserData: [*c]?*anyopaque, ppTokenizer: [*c][*c]fts5_tokenizer_v2) callconv(.c) c_int = null,
};
pub const fts5_api = struct_fts5_api;

pub const __VERSION__ = "Aro aro-zig";
pub const __Aro__ = "";
pub const __STDC__ = @as(c_int, 1);
pub const __STDC_HOSTED__ = @as(c_int, 1);
pub const __STDC_UTF_16__ = @as(c_int, 1);
pub const __STDC_UTF_32__ = @as(c_int, 1);
pub const __STDC_EMBED_NOT_FOUND__ = @as(c_int, 0);
pub const __STDC_EMBED_FOUND__ = @as(c_int, 1);
pub const __STDC_EMBED_EMPTY__ = @as(c_int, 2);
pub const __STDC_VERSION__ = @as(c_long, 201710);
pub const __GNUC__ = @as(c_int, 7);
pub const __GNUC_MINOR__ = @as(c_int, 1);
pub const __GNUC_PATCHLEVEL__ = @as(c_int, 0);
pub const __ARO_EMULATE_CLANG__ = @as(c_int, 1);
pub const __ARO_EMULATE_GCC__ = @as(c_int, 2);
pub const __ARO_EMULATE_MSVC__ = @as(c_int, 3);
pub const __ARO_EMULATE__ = __ARO_EMULATE_GCC__;
pub inline fn __building_module(x: anytype) @TypeOf(@as(c_int, 0)) {
    _ = &x;
    return @as(c_int, 0);
}
pub const linux = @as(c_int, 1);
pub const __linux = @as(c_int, 1);
pub const __linux__ = @as(c_int, 1);
pub const unix = @as(c_int, 1);
pub const __unix = @as(c_int, 1);
pub const __unix__ = @as(c_int, 1);
pub const __code_model_small__ = @as(c_int, 1);
pub const __amd64__ = @as(c_int, 1);
pub const __amd64 = @as(c_int, 1);
pub const __x86_64__ = @as(c_int, 1);
pub const __x86_64 = @as(c_int, 1);
pub const __SEG_GS = @as(c_int, 1);
pub const __SEG_FS = @as(c_int, 1);
pub const __seg_gs = @compileError("unable to translate macro: undefined identifier `address_space`"); // <builtin>:32:9
pub const __seg_fs = @compileError("unable to translate macro: undefined identifier `address_space`"); // <builtin>:33:9
pub const __LAHF_SAHF__ = @as(c_int, 1);
pub const __AES__ = @as(c_int, 1);
pub const __PCLMUL__ = @as(c_int, 1);
pub const __LZCNT__ = @as(c_int, 1);
pub const __RDRND__ = @as(c_int, 1);
pub const __FSGSBASE__ = @as(c_int, 1);
pub const __BMI__ = @as(c_int, 1);
pub const __BMI2__ = @as(c_int, 1);
pub const __POPCNT__ = @as(c_int, 1);
pub const __PRFCHW__ = @as(c_int, 1);
pub const __RDSEED__ = @as(c_int, 1);
pub const __ADX__ = @as(c_int, 1);
pub const __MWAITX__ = @as(c_int, 1);
pub const __MOVBE__ = @as(c_int, 1);
pub const __SSE4A__ = @as(c_int, 1);
pub const __FMA__ = @as(c_int, 1);
pub const __F16C__ = @as(c_int, 1);
pub const __SHA__ = @as(c_int, 1);
pub const __FXSR__ = @as(c_int, 1);
pub const __XSAVE__ = @as(c_int, 1);
pub const __XSAVEOPT__ = @as(c_int, 1);
pub const __XSAVEC__ = @as(c_int, 1);
pub const __XSAVES__ = @as(c_int, 1);
pub const __CLFLUSHOPT__ = @as(c_int, 1);
pub const __CLZERO__ = @as(c_int, 1);
pub const __CRC32__ = @as(c_int, 1);
pub const __AVX2__ = @as(c_int, 1);
pub const __AVX__ = @as(c_int, 1);
pub const __SSE4_2__ = @as(c_int, 1);
pub const __SSE4_1__ = @as(c_int, 1);
pub const __SSSE3__ = @as(c_int, 1);
pub const __SSE3__ = @as(c_int, 1);
pub const __SSE2__ = @as(c_int, 1);
pub const __SSE__ = @as(c_int, 1);
pub const __SSE_MATH__ = @as(c_int, 1);
pub const __MMX__ = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_8 = @as(c_int, 1);
pub const __SIZEOF_FLOAT128__ = @as(c_int, 16);
pub const _LP64 = @as(c_int, 1);
pub const __LP64__ = @as(c_int, 1);
pub const __FLOAT128__ = @as(c_int, 1);
pub const __ORDER_LITTLE_ENDIAN__ = @as(c_int, 1234);
pub const __ORDER_BIG_ENDIAN__ = @as(c_int, 4321);
pub const __ORDER_PDP_ENDIAN__ = @as(c_int, 3412);
pub const __BYTE_ORDER__ = __ORDER_LITTLE_ENDIAN__;
pub const __LITTLE_ENDIAN__ = @as(c_int, 1);
pub const __ELF__ = @as(c_int, 1);
pub const __ATOMIC_RELAXED = @as(c_int, 0);
pub const __ATOMIC_CONSUME = @as(c_int, 1);
pub const __ATOMIC_ACQUIRE = @as(c_int, 2);
pub const __ATOMIC_RELEASE = @as(c_int, 3);
pub const __ATOMIC_ACQ_REL = @as(c_int, 4);
pub const __ATOMIC_SEQ_CST = @as(c_int, 5);
pub const __ATOMIC_BOOL_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_CHAR_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_CHAR16_T_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_CHAR32_T_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_WCHAR_T_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_SHORT_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_INT_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_LONG_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_LLONG_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_POINTER_LOCK_FREE = @as(c_int, 1);
pub const __CHAR_BIT__ = @as(c_int, 8);
pub const __BOOL_WIDTH__ = @as(c_int, 8);
pub const __SCHAR_MAX__ = @as(c_int, 127);
pub const __SCHAR_WIDTH__ = @as(c_int, 8);
pub const __SHRT_MAX__ = @as(c_int, 32767);
pub const __SHRT_WIDTH__ = @as(c_int, 16);
pub const __INT_MAX__ = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __INT_WIDTH__ = @as(c_int, 32);
pub const __LONG_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __LONG_WIDTH__ = @as(c_int, 64);
pub const __LONG_LONG_MAX__ = @as(c_longlong, 9223372036854775807);
pub const __LONG_LONG_WIDTH__ = @as(c_int, 64);
pub const __WCHAR_MAX__ = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __WCHAR_WIDTH__ = @as(c_int, 32);
pub const __INTMAX_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INTMAX_WIDTH__ = @as(c_int, 64);
pub const __SIZE_MAX__ = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __SIZE_WIDTH__ = @as(c_int, 64);
pub const __UINTMAX_MAX__ = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __UINTMAX_WIDTH__ = @as(c_int, 64);
pub const __PTRDIFF_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __PTRDIFF_WIDTH__ = @as(c_int, 64);
pub const __INTPTR_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INTPTR_WIDTH__ = @as(c_int, 64);
pub const __UINTPTR_MAX__ = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __UINTPTR_WIDTH__ = @as(c_int, 64);
pub const __SIG_ATOMIC_MAX__ = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __SIG_ATOMIC_WIDTH__ = @as(c_int, 32);
pub const __BITINT_MAXWIDTH__ = __helpers.promoteIntLiteral(c_int, 65535, .decimal);
pub const __SIZEOF_FLOAT__ = @as(c_int, 4);
pub const __SIZEOF_DOUBLE__ = @as(c_int, 8);
pub const __SIZEOF_LONG_DOUBLE__ = @as(c_int, 10);
pub const __SIZEOF_SHORT__ = @as(c_int, 2);
pub const __SIZEOF_INT__ = @as(c_int, 4);
pub const __SIZEOF_LONG__ = @as(c_int, 8);
pub const __SIZEOF_LONG_LONG__ = @as(c_int, 8);
pub const __SIZEOF_POINTER__ = @as(c_int, 8);
pub const __SIZEOF_PTRDIFF_T__ = @as(c_int, 8);
pub const __SIZEOF_SIZE_T__ = @as(c_int, 8);
pub const __SIZEOF_WCHAR_T__ = @as(c_int, 4);
pub const __SIZEOF_INT128__ = @as(c_int, 16);
pub const __INTPTR_TYPE__ = c_long;
pub const __UINTPTR_TYPE__ = c_ulong;
pub const __INTMAX_TYPE__ = c_long;
pub const __INTMAX_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `L`"); // <builtin>:142:9
pub const __UINTMAX_TYPE__ = c_ulong;
pub const __UINTMAX_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `UL`"); // <builtin>:144:9
pub const __PTRDIFF_TYPE__ = c_long;
pub const __SIZE_TYPE__ = c_ulong;
pub const __WCHAR_TYPE__ = c_int;
pub const __CHAR16_TYPE__ = c_ushort;
pub const __CHAR32_TYPE__ = c_uint;
pub const __INT8_TYPE__ = i8;
pub const __INT8_FMTd__ = "hhd";
pub const __INT8_FMTi__ = "hhi";
pub const __INT8_C_SUFFIX__ = "";
pub const __INT16_TYPE__ = c_short;
pub const __INT16_FMTd__ = "hd";
pub const __INT16_FMTi__ = "hi";
pub const __INT16_C_SUFFIX__ = "";
pub const __INT32_TYPE__ = c_int;
pub const __INT32_FMTd__ = "d";
pub const __INT32_FMTi__ = "i";
pub const __INT32_C_SUFFIX__ = "";
pub const __INT64_TYPE__ = c_long;
pub const __INT64_FMTd__ = "ld";
pub const __INT64_FMTi__ = "li";
pub const __INT64_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `L`"); // <builtin>:165:9
pub const __UINT8_TYPE__ = u8;
pub const __UINT8_FMTo__ = "hho";
pub const __UINT8_FMTu__ = "hhu";
pub const __UINT8_FMTx__ = "hhx";
pub const __UINT8_FMTX__ = "hhX";
pub const __UINT8_C_SUFFIX__ = "";
pub const __UINT8_MAX__ = @as(c_int, 255);
pub const __INT8_MAX__ = @as(c_int, 127);
pub const __UINT16_TYPE__ = c_ushort;
pub const __UINT16_FMTo__ = "ho";
pub const __UINT16_FMTu__ = "hu";
pub const __UINT16_FMTx__ = "hx";
pub const __UINT16_FMTX__ = "hX";
pub const __UINT16_C_SUFFIX__ = "";
pub const __UINT16_MAX__ = __helpers.promoteIntLiteral(c_int, 65535, .decimal);
pub const __INT16_MAX__ = @as(c_int, 32767);
pub const __UINT32_TYPE__ = c_uint;
pub const __UINT32_FMTo__ = "o";
pub const __UINT32_FMTu__ = "u";
pub const __UINT32_FMTx__ = "x";
pub const __UINT32_FMTX__ = "X";
pub const __UINT32_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `U`"); // <builtin>:187:9
pub const __UINT32_MAX__ = __helpers.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const __INT32_MAX__ = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __UINT64_TYPE__ = c_ulong;
pub const __UINT64_FMTo__ = "lo";
pub const __UINT64_FMTu__ = "lu";
pub const __UINT64_FMTx__ = "lx";
pub const __UINT64_FMTX__ = "lX";
pub const __UINT64_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `UL`"); // <builtin>:195:9
pub const __UINT64_MAX__ = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __INT64_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INT_LEAST8_TYPE__ = i8;
pub const __INT_LEAST8_MAX__ = @as(c_int, 127);
pub const __INT_LEAST8_WIDTH__ = @as(c_int, 8);
pub const INT_LEAST8_FMTd__ = "hhd";
pub const INT_LEAST8_FMTi__ = "hhi";
pub const __UINT_LEAST8_TYPE__ = u8;
pub const __UINT_LEAST8_MAX__ = @as(c_int, 255);
pub const UINT_LEAST8_FMTo__ = "hho";
pub const UINT_LEAST8_FMTu__ = "hhu";
pub const UINT_LEAST8_FMTx__ = "hhx";
pub const UINT_LEAST8_FMTX__ = "hhX";
pub const __INT_FAST8_TYPE__ = i8;
pub const __INT_FAST8_MAX__ = @as(c_int, 127);
pub const __INT_FAST8_WIDTH__ = @as(c_int, 8);
pub const INT_FAST8_FMTd__ = "hhd";
pub const INT_FAST8_FMTi__ = "hhi";
pub const __UINT_FAST8_TYPE__ = u8;
pub const __UINT_FAST8_MAX__ = @as(c_int, 255);
pub const UINT_FAST8_FMTo__ = "hho";
pub const UINT_FAST8_FMTu__ = "hhu";
pub const UINT_FAST8_FMTx__ = "hhx";
pub const UINT_FAST8_FMTX__ = "hhX";
pub const __INT_LEAST16_TYPE__ = c_short;
pub const __INT_LEAST16_MAX__ = @as(c_int, 32767);
pub const __INT_LEAST16_WIDTH__ = @as(c_int, 16);
pub const INT_LEAST16_FMTd__ = "hd";
pub const INT_LEAST16_FMTi__ = "hi";
pub const __UINT_LEAST16_TYPE__ = c_ushort;
pub const __UINT_LEAST16_MAX__ = __helpers.promoteIntLiteral(c_int, 65535, .decimal);
pub const UINT_LEAST16_FMTo__ = "ho";
pub const UINT_LEAST16_FMTu__ = "hu";
pub const UINT_LEAST16_FMTx__ = "hx";
pub const UINT_LEAST16_FMTX__ = "hX";
pub const __INT_FAST16_TYPE__ = c_short;
pub const __INT_FAST16_MAX__ = @as(c_int, 32767);
pub const __INT_FAST16_WIDTH__ = @as(c_int, 16);
pub const INT_FAST16_FMTd__ = "hd";
pub const INT_FAST16_FMTi__ = "hi";
pub const __UINT_FAST16_TYPE__ = c_ushort;
pub const __UINT_FAST16_MAX__ = __helpers.promoteIntLiteral(c_int, 65535, .decimal);
pub const UINT_FAST16_FMTo__ = "ho";
pub const UINT_FAST16_FMTu__ = "hu";
pub const UINT_FAST16_FMTx__ = "hx";
pub const UINT_FAST16_FMTX__ = "hX";
pub const __INT_LEAST32_TYPE__ = c_int;
pub const __INT_LEAST32_MAX__ = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __INT_LEAST32_WIDTH__ = @as(c_int, 32);
pub const INT_LEAST32_FMTd__ = "d";
pub const INT_LEAST32_FMTi__ = "i";
pub const __UINT_LEAST32_TYPE__ = c_uint;
pub const __UINT_LEAST32_MAX__ = __helpers.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const UINT_LEAST32_FMTo__ = "o";
pub const UINT_LEAST32_FMTu__ = "u";
pub const UINT_LEAST32_FMTx__ = "x";
pub const UINT_LEAST32_FMTX__ = "X";
pub const __INT_FAST32_TYPE__ = c_int;
pub const __INT_FAST32_MAX__ = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __INT_FAST32_WIDTH__ = @as(c_int, 32);
pub const INT_FAST32_FMTd__ = "d";
pub const INT_FAST32_FMTi__ = "i";
pub const __UINT_FAST32_TYPE__ = c_uint;
pub const __UINT_FAST32_MAX__ = __helpers.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const UINT_FAST32_FMTo__ = "o";
pub const UINT_FAST32_FMTu__ = "u";
pub const UINT_FAST32_FMTx__ = "x";
pub const UINT_FAST32_FMTX__ = "X";
pub const __INT_LEAST64_TYPE__ = c_long;
pub const __INT_LEAST64_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INT_LEAST64_WIDTH__ = @as(c_int, 64);
pub const INT_LEAST64_FMTd__ = "ld";
pub const INT_LEAST64_FMTi__ = "li";
pub const __UINT_LEAST64_TYPE__ = c_ulong;
pub const __UINT_LEAST64_MAX__ = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const UINT_LEAST64_FMTo__ = "lo";
pub const UINT_LEAST64_FMTu__ = "lu";
pub const UINT_LEAST64_FMTx__ = "lx";
pub const UINT_LEAST64_FMTX__ = "lX";
pub const __INT_FAST64_TYPE__ = c_long;
pub const __INT_FAST64_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INT_FAST64_WIDTH__ = @as(c_int, 64);
pub const INT_FAST64_FMTd__ = "ld";
pub const INT_FAST64_FMTi__ = "li";
pub const __UINT_FAST64_TYPE__ = c_ulong;
pub const __UINT_FAST64_MAX__ = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const UINT_FAST64_FMTo__ = "lo";
pub const UINT_FAST64_FMTu__ = "lu";
pub const UINT_FAST64_FMTx__ = "lx";
pub const UINT_FAST64_FMTX__ = "lX";
pub const __FLT16_DENORM_MIN__ = @as(f16, 5.9604644775390625e-8);
pub const __FLT16_HAS_DENORM__ = "";
pub const __FLT16_DIG__ = @as(c_int, 3);
pub const __FLT16_DECIMAL_DIG__ = @as(c_int, 5);
pub const __FLT16_EPSILON__ = @as(f16, 9.765625e-4);
pub const __FLT16_HAS_INFINITY__ = "";
pub const __FLT16_HAS_QUIET_NAN__ = "";
pub const __FLT16_MANT_DIG__ = @as(c_int, 11);
pub const __FLT16_MAX_10_EXP__ = @as(c_int, 4);
pub const __FLT16_MAX_EXP__ = @as(c_int, 16);
pub const __FLT16_MAX__ = @as(f16, 6.5504e+4);
pub const __FLT16_MIN_10_EXP__ = -@as(c_int, 4);
pub const __FLT16_MIN_EXP__ = -@as(c_int, 13);
pub const __FLT16_MIN__ = @as(f16, 6.103515625e-5);
pub const __FLT_DENORM_MIN__ = @as(f32, 1.40129846e-45);
pub const __FLT_HAS_DENORM__ = "";
pub const __FLT_DIG__ = @as(c_int, 6);
pub const __FLT_DECIMAL_DIG__ = @as(c_int, 9);
pub const __FLT_EPSILON__ = @as(f32, 1.19209290e-7);
pub const __FLT_HAS_INFINITY__ = "";
pub const __FLT_HAS_QUIET_NAN__ = "";
pub const __FLT_MANT_DIG__ = @as(c_int, 24);
pub const __FLT_MAX_10_EXP__ = @as(c_int, 38);
pub const __FLT_MAX_EXP__ = @as(c_int, 128);
pub const __FLT_MAX__ = @as(f32, 3.40282347e+38);
pub const __FLT_MIN_10_EXP__ = -@as(c_int, 37);
pub const __FLT_MIN_EXP__ = -@as(c_int, 125);
pub const __FLT_MIN__ = @as(f32, 1.17549435e-38);
pub const __DBL_DENORM_MIN__ = @as(f64, 4.9406564584124654e-324);
pub const __DBL_HAS_DENORM__ = "";
pub const __DBL_DIG__ = @as(c_int, 15);
pub const __DBL_DECIMAL_DIG__ = @as(c_int, 17);
pub const __DBL_EPSILON__ = @as(f64, 2.2204460492503131e-16);
pub const __DBL_HAS_INFINITY__ = "";
pub const __DBL_HAS_QUIET_NAN__ = "";
pub const __DBL_MANT_DIG__ = @as(c_int, 53);
pub const __DBL_MAX_10_EXP__ = @as(c_int, 308);
pub const __DBL_MAX_EXP__ = @as(c_int, 1024);
pub const __DBL_MAX__ = @as(f64, 1.7976931348623157e+308);
pub const __DBL_MIN_10_EXP__ = -@as(c_int, 307);
pub const __DBL_MIN_EXP__ = -@as(c_int, 1021);
pub const __DBL_MIN__ = @as(f64, 2.2250738585072014e-308);
pub const __LDBL_DENORM_MIN__ = @as(c_longdouble, 3.64519953188247460253e-4951);
pub const __LDBL_HAS_DENORM__ = "";
pub const __LDBL_DIG__ = @as(c_int, 18);
pub const __LDBL_DECIMAL_DIG__ = @as(c_int, 21);
pub const __LDBL_EPSILON__ = @as(c_longdouble, 1.08420217248550443401e-19);
pub const __LDBL_HAS_INFINITY__ = "";
pub const __LDBL_HAS_QUIET_NAN__ = "";
pub const __LDBL_MANT_DIG__ = @as(c_int, 64);
pub const __LDBL_MAX_10_EXP__ = @as(c_int, 4932);
pub const __LDBL_MAX_EXP__ = @as(c_int, 16384);
pub const __LDBL_MAX__ = @as(c_longdouble, 1.18973149535723176502e+4932);
pub const __LDBL_MIN_10_EXP__ = -@as(c_int, 4931);
pub const __LDBL_MIN_EXP__ = -@as(c_int, 16381);
pub const __LDBL_MIN__ = @as(c_longdouble, 3.36210314311209350626e-4932);
pub const __FLT_EVAL_METHOD__ = @as(c_int, 0);
pub const __FLT_RADIX__ = @as(c_int, 2);
pub const __DECIMAL_DIG__ = __LDBL_DECIMAL_DIG__;
pub const __pic__ = @as(c_int, 2);
pub const __PIC__ = @as(c_int, 2);
pub const __GLIBC_MINOR__ = @as(c_int, 42);
pub const _REENTRANT = @as(c_int, 1);
pub const SQLITE3_H = "";
pub const __STDC_VERSION_STDARG_H__ = @as(c_int, 0);
pub const va_start = @compileError("unable to translate macro: undefined identifier `__builtin_va_start`"); // /opt/zig/lib/compiler/aro/include/stdarg.h:12:9
pub const va_end = @compileError("unable to translate macro: undefined identifier `__builtin_va_end`"); // /opt/zig/lib/compiler/aro/include/stdarg.h:14:9
pub const va_arg = @compileError("unable to translate macro: undefined identifier `__builtin_va_arg`"); // /opt/zig/lib/compiler/aro/include/stdarg.h:15:9
pub const __va_copy = @compileError("unable to translate macro: undefined identifier `__builtin_va_copy`"); // /opt/zig/lib/compiler/aro/include/stdarg.h:18:9
pub const va_copy = @compileError("unable to translate macro: undefined identifier `__builtin_va_copy`"); // /opt/zig/lib/compiler/aro/include/stdarg.h:22:9
pub const __GNUC_VA_LIST = @as(c_int, 1);
pub const SQLITE_EXTERN = @compileError("unable to translate C expr: unexpected token 'extern'"); // /usr/include/sqlite3.h:72:10
pub const SQLITE_API = "";
pub const SQLITE_CDECL = "";
pub const SQLITE_APICALL = "";
pub const SQLITE_STDCALL = "";
pub const SQLITE_CALLBACK = "";
pub const SQLITE_SYSAPI = "";
pub const SQLITE_DEPRECATED = "";
pub const SQLITE_EXPERIMENTAL = "";
pub const SQLITE_VERSION = "3.50.4";
pub const SQLITE_VERSION_NUMBER = __helpers.promoteIntLiteral(c_int, 3050004, .decimal);
pub const SQLITE_SOURCE_ID = "2025-07-30 19:33:53 4d8adfb30e03f9cf27f800a2c1ba3c48fb4ca1b08b0f5ed59a4d5ecbf45ealt1";
pub const SQLITE_OK = @as(c_int, 0);
pub const SQLITE_ERROR = @as(c_int, 1);
pub const SQLITE_INTERNAL = @as(c_int, 2);
pub const SQLITE_PERM = @as(c_int, 3);
pub const SQLITE_ABORT = @as(c_int, 4);
pub const SQLITE_BUSY = @as(c_int, 5);
pub const SQLITE_LOCKED = @as(c_int, 6);
pub const SQLITE_NOMEM = @as(c_int, 7);
pub const SQLITE_READONLY = @as(c_int, 8);
pub const SQLITE_INTERRUPT = @as(c_int, 9);
pub const SQLITE_IOERR = @as(c_int, 10);
pub const SQLITE_CORRUPT = @as(c_int, 11);
pub const SQLITE_NOTFOUND = @as(c_int, 12);
pub const SQLITE_FULL = @as(c_int, 13);
pub const SQLITE_CANTOPEN = @as(c_int, 14);
pub const SQLITE_PROTOCOL = @as(c_int, 15);
pub const SQLITE_EMPTY = @as(c_int, 16);
pub const SQLITE_SCHEMA = @as(c_int, 17);
pub const SQLITE_TOOBIG = @as(c_int, 18);
pub const SQLITE_CONSTRAINT = @as(c_int, 19);
pub const SQLITE_MISMATCH = @as(c_int, 20);
pub const SQLITE_MISUSE = @as(c_int, 21);
pub const SQLITE_NOLFS = @as(c_int, 22);
pub const SQLITE_AUTH = @as(c_int, 23);
pub const SQLITE_FORMAT = @as(c_int, 24);
pub const SQLITE_RANGE = @as(c_int, 25);
pub const SQLITE_NOTADB = @as(c_int, 26);
pub const SQLITE_NOTICE = @as(c_int, 27);
pub const SQLITE_WARNING = @as(c_int, 28);
pub const SQLITE_ROW = @as(c_int, 100);
pub const SQLITE_DONE = @as(c_int, 101);
pub const SQLITE_ERROR_MISSING_COLLSEQ = SQLITE_ERROR | (@as(c_int, 1) << @as(c_int, 8));
pub const SQLITE_ERROR_RETRY = SQLITE_ERROR | (@as(c_int, 2) << @as(c_int, 8));
pub const SQLITE_ERROR_SNAPSHOT = SQLITE_ERROR | (@as(c_int, 3) << @as(c_int, 8));
pub const SQLITE_IOERR_READ = SQLITE_IOERR | (@as(c_int, 1) << @as(c_int, 8));
pub const SQLITE_IOERR_SHORT_READ = SQLITE_IOERR | (@as(c_int, 2) << @as(c_int, 8));
pub const SQLITE_IOERR_WRITE = SQLITE_IOERR | (@as(c_int, 3) << @as(c_int, 8));
pub const SQLITE_IOERR_FSYNC = SQLITE_IOERR | (@as(c_int, 4) << @as(c_int, 8));
pub const SQLITE_IOERR_DIR_FSYNC = SQLITE_IOERR | (@as(c_int, 5) << @as(c_int, 8));
pub const SQLITE_IOERR_TRUNCATE = SQLITE_IOERR | (@as(c_int, 6) << @as(c_int, 8));
pub const SQLITE_IOERR_FSTAT = SQLITE_IOERR | (@as(c_int, 7) << @as(c_int, 8));
pub const SQLITE_IOERR_UNLOCK = SQLITE_IOERR | (@as(c_int, 8) << @as(c_int, 8));
pub const SQLITE_IOERR_RDLOCK = SQLITE_IOERR | (@as(c_int, 9) << @as(c_int, 8));
pub const SQLITE_IOERR_DELETE = SQLITE_IOERR | (@as(c_int, 10) << @as(c_int, 8));
pub const SQLITE_IOERR_BLOCKED = SQLITE_IOERR | (@as(c_int, 11) << @as(c_int, 8));
pub const SQLITE_IOERR_NOMEM = SQLITE_IOERR | (@as(c_int, 12) << @as(c_int, 8));
pub const SQLITE_IOERR_ACCESS = SQLITE_IOERR | (@as(c_int, 13) << @as(c_int, 8));
pub const SQLITE_IOERR_CHECKRESERVEDLOCK = SQLITE_IOERR | (@as(c_int, 14) << @as(c_int, 8));
pub const SQLITE_IOERR_LOCK = SQLITE_IOERR | (@as(c_int, 15) << @as(c_int, 8));
pub const SQLITE_IOERR_CLOSE = SQLITE_IOERR | (@as(c_int, 16) << @as(c_int, 8));
pub const SQLITE_IOERR_DIR_CLOSE = SQLITE_IOERR | (@as(c_int, 17) << @as(c_int, 8));
pub const SQLITE_IOERR_SHMOPEN = SQLITE_IOERR | (@as(c_int, 18) << @as(c_int, 8));
pub const SQLITE_IOERR_SHMSIZE = SQLITE_IOERR | (@as(c_int, 19) << @as(c_int, 8));
pub const SQLITE_IOERR_SHMLOCK = SQLITE_IOERR | (@as(c_int, 20) << @as(c_int, 8));
pub const SQLITE_IOERR_SHMMAP = SQLITE_IOERR | (@as(c_int, 21) << @as(c_int, 8));
pub const SQLITE_IOERR_SEEK = SQLITE_IOERR | (@as(c_int, 22) << @as(c_int, 8));
pub const SQLITE_IOERR_DELETE_NOENT = SQLITE_IOERR | (@as(c_int, 23) << @as(c_int, 8));
pub const SQLITE_IOERR_MMAP = SQLITE_IOERR | (@as(c_int, 24) << @as(c_int, 8));
pub const SQLITE_IOERR_GETTEMPPATH = SQLITE_IOERR | (@as(c_int, 25) << @as(c_int, 8));
pub const SQLITE_IOERR_CONVPATH = SQLITE_IOERR | (@as(c_int, 26) << @as(c_int, 8));
pub const SQLITE_IOERR_VNODE = SQLITE_IOERR | (@as(c_int, 27) << @as(c_int, 8));
pub const SQLITE_IOERR_AUTH = SQLITE_IOERR | (@as(c_int, 28) << @as(c_int, 8));
pub const SQLITE_IOERR_BEGIN_ATOMIC = SQLITE_IOERR | (@as(c_int, 29) << @as(c_int, 8));
pub const SQLITE_IOERR_COMMIT_ATOMIC = SQLITE_IOERR | (@as(c_int, 30) << @as(c_int, 8));
pub const SQLITE_IOERR_ROLLBACK_ATOMIC = SQLITE_IOERR | (@as(c_int, 31) << @as(c_int, 8));
pub const SQLITE_IOERR_DATA = SQLITE_IOERR | (@as(c_int, 32) << @as(c_int, 8));
pub const SQLITE_IOERR_CORRUPTFS = SQLITE_IOERR | (@as(c_int, 33) << @as(c_int, 8));
pub const SQLITE_IOERR_IN_PAGE = SQLITE_IOERR | (@as(c_int, 34) << @as(c_int, 8));
pub const SQLITE_LOCKED_SHAREDCACHE = SQLITE_LOCKED | (@as(c_int, 1) << @as(c_int, 8));
pub const SQLITE_LOCKED_VTAB = SQLITE_LOCKED | (@as(c_int, 2) << @as(c_int, 8));
pub const SQLITE_BUSY_RECOVERY = SQLITE_BUSY | (@as(c_int, 1) << @as(c_int, 8));
pub const SQLITE_BUSY_SNAPSHOT = SQLITE_BUSY | (@as(c_int, 2) << @as(c_int, 8));
pub const SQLITE_BUSY_TIMEOUT = SQLITE_BUSY | (@as(c_int, 3) << @as(c_int, 8));
pub const SQLITE_CANTOPEN_NOTEMPDIR = SQLITE_CANTOPEN | (@as(c_int, 1) << @as(c_int, 8));
pub const SQLITE_CANTOPEN_ISDIR = SQLITE_CANTOPEN | (@as(c_int, 2) << @as(c_int, 8));
pub const SQLITE_CANTOPEN_FULLPATH = SQLITE_CANTOPEN | (@as(c_int, 3) << @as(c_int, 8));
pub const SQLITE_CANTOPEN_CONVPATH = SQLITE_CANTOPEN | (@as(c_int, 4) << @as(c_int, 8));
pub const SQLITE_CANTOPEN_DIRTYWAL = SQLITE_CANTOPEN | (@as(c_int, 5) << @as(c_int, 8));
pub const SQLITE_CANTOPEN_SYMLINK = SQLITE_CANTOPEN | (@as(c_int, 6) << @as(c_int, 8));
pub const SQLITE_CORRUPT_VTAB = SQLITE_CORRUPT | (@as(c_int, 1) << @as(c_int, 8));
pub const SQLITE_CORRUPT_SEQUENCE = SQLITE_CORRUPT | (@as(c_int, 2) << @as(c_int, 8));
pub const SQLITE_CORRUPT_INDEX = SQLITE_CORRUPT | (@as(c_int, 3) << @as(c_int, 8));
pub const SQLITE_READONLY_RECOVERY = SQLITE_READONLY | (@as(c_int, 1) << @as(c_int, 8));
pub const SQLITE_READONLY_CANTLOCK = SQLITE_READONLY | (@as(c_int, 2) << @as(c_int, 8));
pub const SQLITE_READONLY_ROLLBACK = SQLITE_READONLY | (@as(c_int, 3) << @as(c_int, 8));
pub const SQLITE_READONLY_DBMOVED = SQLITE_READONLY | (@as(c_int, 4) << @as(c_int, 8));
pub const SQLITE_READONLY_CANTINIT = SQLITE_READONLY | (@as(c_int, 5) << @as(c_int, 8));
pub const SQLITE_READONLY_DIRECTORY = SQLITE_READONLY | (@as(c_int, 6) << @as(c_int, 8));
pub const SQLITE_ABORT_ROLLBACK = SQLITE_ABORT | (@as(c_int, 2) << @as(c_int, 8));
pub const SQLITE_CONSTRAINT_CHECK = SQLITE_CONSTRAINT | (@as(c_int, 1) << @as(c_int, 8));
pub const SQLITE_CONSTRAINT_COMMITHOOK = SQLITE_CONSTRAINT | (@as(c_int, 2) << @as(c_int, 8));
pub const SQLITE_CONSTRAINT_FOREIGNKEY = SQLITE_CONSTRAINT | (@as(c_int, 3) << @as(c_int, 8));
pub const SQLITE_CONSTRAINT_FUNCTION = SQLITE_CONSTRAINT | (@as(c_int, 4) << @as(c_int, 8));
pub const SQLITE_CONSTRAINT_NOTNULL = SQLITE_CONSTRAINT | (@as(c_int, 5) << @as(c_int, 8));
pub const SQLITE_CONSTRAINT_PRIMARYKEY = SQLITE_CONSTRAINT | (@as(c_int, 6) << @as(c_int, 8));
pub const SQLITE_CONSTRAINT_TRIGGER = SQLITE_CONSTRAINT | (@as(c_int, 7) << @as(c_int, 8));
pub const SQLITE_CONSTRAINT_UNIQUE = SQLITE_CONSTRAINT | (@as(c_int, 8) << @as(c_int, 8));
pub const SQLITE_CONSTRAINT_VTAB = SQLITE_CONSTRAINT | (@as(c_int, 9) << @as(c_int, 8));
pub const SQLITE_CONSTRAINT_ROWID = SQLITE_CONSTRAINT | (@as(c_int, 10) << @as(c_int, 8));
pub const SQLITE_CONSTRAINT_PINNED = SQLITE_CONSTRAINT | (@as(c_int, 11) << @as(c_int, 8));
pub const SQLITE_CONSTRAINT_DATATYPE = SQLITE_CONSTRAINT | (@as(c_int, 12) << @as(c_int, 8));
pub const SQLITE_NOTICE_RECOVER_WAL = SQLITE_NOTICE | (@as(c_int, 1) << @as(c_int, 8));
pub const SQLITE_NOTICE_RECOVER_ROLLBACK = SQLITE_NOTICE | (@as(c_int, 2) << @as(c_int, 8));
pub const SQLITE_NOTICE_RBU = SQLITE_NOTICE | (@as(c_int, 3) << @as(c_int, 8));
pub const SQLITE_WARNING_AUTOINDEX = SQLITE_WARNING | (@as(c_int, 1) << @as(c_int, 8));
pub const SQLITE_AUTH_USER = SQLITE_AUTH | (@as(c_int, 1) << @as(c_int, 8));
pub const SQLITE_OK_LOAD_PERMANENTLY = SQLITE_OK | (@as(c_int, 1) << @as(c_int, 8));
pub const SQLITE_OK_SYMLINK = SQLITE_OK | (@as(c_int, 2) << @as(c_int, 8));
pub const SQLITE_OPEN_READONLY = @as(c_int, 0x00000001);
pub const SQLITE_OPEN_READWRITE = @as(c_int, 0x00000002);
pub const SQLITE_OPEN_CREATE = @as(c_int, 0x00000004);
pub const SQLITE_OPEN_DELETEONCLOSE = @as(c_int, 0x00000008);
pub const SQLITE_OPEN_EXCLUSIVE = @as(c_int, 0x00000010);
pub const SQLITE_OPEN_AUTOPROXY = @as(c_int, 0x00000020);
pub const SQLITE_OPEN_URI = @as(c_int, 0x00000040);
pub const SQLITE_OPEN_MEMORY = @as(c_int, 0x00000080);
pub const SQLITE_OPEN_MAIN_DB = @as(c_int, 0x00000100);
pub const SQLITE_OPEN_TEMP_DB = @as(c_int, 0x00000200);
pub const SQLITE_OPEN_TRANSIENT_DB = @as(c_int, 0x00000400);
pub const SQLITE_OPEN_MAIN_JOURNAL = @as(c_int, 0x00000800);
pub const SQLITE_OPEN_TEMP_JOURNAL = @as(c_int, 0x00001000);
pub const SQLITE_OPEN_SUBJOURNAL = @as(c_int, 0x00002000);
pub const SQLITE_OPEN_SUPER_JOURNAL = @as(c_int, 0x00004000);
pub const SQLITE_OPEN_NOMUTEX = __helpers.promoteIntLiteral(c_int, 0x00008000, .hex);
pub const SQLITE_OPEN_FULLMUTEX = __helpers.promoteIntLiteral(c_int, 0x00010000, .hex);
pub const SQLITE_OPEN_SHAREDCACHE = __helpers.promoteIntLiteral(c_int, 0x00020000, .hex);
pub const SQLITE_OPEN_PRIVATECACHE = __helpers.promoteIntLiteral(c_int, 0x00040000, .hex);
pub const SQLITE_OPEN_WAL = __helpers.promoteIntLiteral(c_int, 0x00080000, .hex);
pub const SQLITE_OPEN_NOFOLLOW = __helpers.promoteIntLiteral(c_int, 0x01000000, .hex);
pub const SQLITE_OPEN_EXRESCODE = __helpers.promoteIntLiteral(c_int, 0x02000000, .hex);
pub const SQLITE_OPEN_MASTER_JOURNAL = @as(c_int, 0x00004000);
pub const SQLITE_IOCAP_ATOMIC = @as(c_int, 0x00000001);
pub const SQLITE_IOCAP_ATOMIC512 = @as(c_int, 0x00000002);
pub const SQLITE_IOCAP_ATOMIC1K = @as(c_int, 0x00000004);
pub const SQLITE_IOCAP_ATOMIC2K = @as(c_int, 0x00000008);
pub const SQLITE_IOCAP_ATOMIC4K = @as(c_int, 0x00000010);
pub const SQLITE_IOCAP_ATOMIC8K = @as(c_int, 0x00000020);
pub const SQLITE_IOCAP_ATOMIC16K = @as(c_int, 0x00000040);
pub const SQLITE_IOCAP_ATOMIC32K = @as(c_int, 0x00000080);
pub const SQLITE_IOCAP_ATOMIC64K = @as(c_int, 0x00000100);
pub const SQLITE_IOCAP_SAFE_APPEND = @as(c_int, 0x00000200);
pub const SQLITE_IOCAP_SEQUENTIAL = @as(c_int, 0x00000400);
pub const SQLITE_IOCAP_UNDELETABLE_WHEN_OPEN = @as(c_int, 0x00000800);
pub const SQLITE_IOCAP_POWERSAFE_OVERWRITE = @as(c_int, 0x00001000);
pub const SQLITE_IOCAP_IMMUTABLE = @as(c_int, 0x00002000);
pub const SQLITE_IOCAP_BATCH_ATOMIC = @as(c_int, 0x00004000);
pub const SQLITE_IOCAP_SUBPAGE_READ = __helpers.promoteIntLiteral(c_int, 0x00008000, .hex);
pub const SQLITE_LOCK_NONE = @as(c_int, 0);
pub const SQLITE_LOCK_SHARED = @as(c_int, 1);
pub const SQLITE_LOCK_RESERVED = @as(c_int, 2);
pub const SQLITE_LOCK_PENDING = @as(c_int, 3);
pub const SQLITE_LOCK_EXCLUSIVE = @as(c_int, 4);
pub const SQLITE_SYNC_NORMAL = @as(c_int, 0x00002);
pub const SQLITE_SYNC_FULL = @as(c_int, 0x00003);
pub const SQLITE_SYNC_DATAONLY = @as(c_int, 0x00010);
pub const SQLITE_FCNTL_LOCKSTATE = @as(c_int, 1);
pub const SQLITE_FCNTL_GET_LOCKPROXYFILE = @as(c_int, 2);
pub const SQLITE_FCNTL_SET_LOCKPROXYFILE = @as(c_int, 3);
pub const SQLITE_FCNTL_LAST_ERRNO = @as(c_int, 4);
pub const SQLITE_FCNTL_SIZE_HINT = @as(c_int, 5);
pub const SQLITE_FCNTL_CHUNK_SIZE = @as(c_int, 6);
pub const SQLITE_FCNTL_FILE_POINTER = @as(c_int, 7);
pub const SQLITE_FCNTL_SYNC_OMITTED = @as(c_int, 8);
pub const SQLITE_FCNTL_WIN32_AV_RETRY = @as(c_int, 9);
pub const SQLITE_FCNTL_PERSIST_WAL = @as(c_int, 10);
pub const SQLITE_FCNTL_OVERWRITE = @as(c_int, 11);
pub const SQLITE_FCNTL_VFSNAME = @as(c_int, 12);
pub const SQLITE_FCNTL_POWERSAFE_OVERWRITE = @as(c_int, 13);
pub const SQLITE_FCNTL_PRAGMA = @as(c_int, 14);
pub const SQLITE_FCNTL_BUSYHANDLER = @as(c_int, 15);
pub const SQLITE_FCNTL_TEMPFILENAME = @as(c_int, 16);
pub const SQLITE_FCNTL_MMAP_SIZE = @as(c_int, 18);
pub const SQLITE_FCNTL_TRACE = @as(c_int, 19);
pub const SQLITE_FCNTL_HAS_MOVED = @as(c_int, 20);
pub const SQLITE_FCNTL_SYNC = @as(c_int, 21);
pub const SQLITE_FCNTL_COMMIT_PHASETWO = @as(c_int, 22);
pub const SQLITE_FCNTL_WIN32_SET_HANDLE = @as(c_int, 23);
pub const SQLITE_FCNTL_WAL_BLOCK = @as(c_int, 24);
pub const SQLITE_FCNTL_ZIPVFS = @as(c_int, 25);
pub const SQLITE_FCNTL_RBU = @as(c_int, 26);
pub const SQLITE_FCNTL_VFS_POINTER = @as(c_int, 27);
pub const SQLITE_FCNTL_JOURNAL_POINTER = @as(c_int, 28);
pub const SQLITE_FCNTL_WIN32_GET_HANDLE = @as(c_int, 29);
pub const SQLITE_FCNTL_PDB = @as(c_int, 30);
pub const SQLITE_FCNTL_BEGIN_ATOMIC_WRITE = @as(c_int, 31);
pub const SQLITE_FCNTL_COMMIT_ATOMIC_WRITE = @as(c_int, 32);
pub const SQLITE_FCNTL_ROLLBACK_ATOMIC_WRITE = @as(c_int, 33);
pub const SQLITE_FCNTL_LOCK_TIMEOUT = @as(c_int, 34);
pub const SQLITE_FCNTL_DATA_VERSION = @as(c_int, 35);
pub const SQLITE_FCNTL_SIZE_LIMIT = @as(c_int, 36);
pub const SQLITE_FCNTL_CKPT_DONE = @as(c_int, 37);
pub const SQLITE_FCNTL_RESERVE_BYTES = @as(c_int, 38);
pub const SQLITE_FCNTL_CKPT_START = @as(c_int, 39);
pub const SQLITE_FCNTL_EXTERNAL_READER = @as(c_int, 40);
pub const SQLITE_FCNTL_CKSM_FILE = @as(c_int, 41);
pub const SQLITE_FCNTL_RESET_CACHE = @as(c_int, 42);
pub const SQLITE_FCNTL_NULL_IO = @as(c_int, 43);
pub const SQLITE_FCNTL_BLOCK_ON_CONNECT = @as(c_int, 44);
pub const SQLITE_GET_LOCKPROXYFILE = SQLITE_FCNTL_GET_LOCKPROXYFILE;
pub const SQLITE_SET_LOCKPROXYFILE = SQLITE_FCNTL_SET_LOCKPROXYFILE;
pub const SQLITE_LAST_ERRNO = SQLITE_FCNTL_LAST_ERRNO;
pub const SQLITE_ACCESS_EXISTS = @as(c_int, 0);
pub const SQLITE_ACCESS_READWRITE = @as(c_int, 1);
pub const SQLITE_ACCESS_READ = @as(c_int, 2);
pub const SQLITE_SHM_UNLOCK = @as(c_int, 1);
pub const SQLITE_SHM_LOCK = @as(c_int, 2);
pub const SQLITE_SHM_SHARED = @as(c_int, 4);
pub const SQLITE_SHM_EXCLUSIVE = @as(c_int, 8);
pub const SQLITE_SHM_NLOCK = @as(c_int, 8);
pub const SQLITE_CONFIG_SINGLETHREAD = @as(c_int, 1);
pub const SQLITE_CONFIG_MULTITHREAD = @as(c_int, 2);
pub const SQLITE_CONFIG_SERIALIZED = @as(c_int, 3);
pub const SQLITE_CONFIG_MALLOC = @as(c_int, 4);
pub const SQLITE_CONFIG_GETMALLOC = @as(c_int, 5);
pub const SQLITE_CONFIG_SCRATCH = @as(c_int, 6);
pub const SQLITE_CONFIG_PAGECACHE = @as(c_int, 7);
pub const SQLITE_CONFIG_HEAP = @as(c_int, 8);
pub const SQLITE_CONFIG_MEMSTATUS = @as(c_int, 9);
pub const SQLITE_CONFIG_MUTEX = @as(c_int, 10);
pub const SQLITE_CONFIG_GETMUTEX = @as(c_int, 11);
pub const SQLITE_CONFIG_LOOKASIDE = @as(c_int, 13);
pub const SQLITE_CONFIG_PCACHE = @as(c_int, 14);
pub const SQLITE_CONFIG_GETPCACHE = @as(c_int, 15);
pub const SQLITE_CONFIG_LOG = @as(c_int, 16);
pub const SQLITE_CONFIG_URI = @as(c_int, 17);
pub const SQLITE_CONFIG_PCACHE2 = @as(c_int, 18);
pub const SQLITE_CONFIG_GETPCACHE2 = @as(c_int, 19);
pub const SQLITE_CONFIG_COVERING_INDEX_SCAN = @as(c_int, 20);
pub const SQLITE_CONFIG_SQLLOG = @as(c_int, 21);
pub const SQLITE_CONFIG_MMAP_SIZE = @as(c_int, 22);
pub const SQLITE_CONFIG_WIN32_HEAPSIZE = @as(c_int, 23);
pub const SQLITE_CONFIG_PCACHE_HDRSZ = @as(c_int, 24);
pub const SQLITE_CONFIG_PMASZ = @as(c_int, 25);
pub const SQLITE_CONFIG_STMTJRNL_SPILL = @as(c_int, 26);
pub const SQLITE_CONFIG_SMALL_MALLOC = @as(c_int, 27);
pub const SQLITE_CONFIG_SORTERREF_SIZE = @as(c_int, 28);
pub const SQLITE_CONFIG_MEMDB_MAXSIZE = @as(c_int, 29);
pub const SQLITE_CONFIG_ROWID_IN_VIEW = @as(c_int, 30);
pub const SQLITE_DBCONFIG_MAINDBNAME = @as(c_int, 1000);
pub const SQLITE_DBCONFIG_LOOKASIDE = @as(c_int, 1001);
pub const SQLITE_DBCONFIG_ENABLE_FKEY = @as(c_int, 1002);
pub const SQLITE_DBCONFIG_ENABLE_TRIGGER = @as(c_int, 1003);
pub const SQLITE_DBCONFIG_ENABLE_FTS3_TOKENIZER = @as(c_int, 1004);
pub const SQLITE_DBCONFIG_ENABLE_LOAD_EXTENSION = @as(c_int, 1005);
pub const SQLITE_DBCONFIG_NO_CKPT_ON_CLOSE = @as(c_int, 1006);
pub const SQLITE_DBCONFIG_ENABLE_QPSG = @as(c_int, 1007);
pub const SQLITE_DBCONFIG_TRIGGER_EQP = @as(c_int, 1008);
pub const SQLITE_DBCONFIG_RESET_DATABASE = @as(c_int, 1009);
pub const SQLITE_DBCONFIG_DEFENSIVE = @as(c_int, 1010);
pub const SQLITE_DBCONFIG_WRITABLE_SCHEMA = @as(c_int, 1011);
pub const SQLITE_DBCONFIG_LEGACY_ALTER_TABLE = @as(c_int, 1012);
pub const SQLITE_DBCONFIG_DQS_DML = @as(c_int, 1013);
pub const SQLITE_DBCONFIG_DQS_DDL = @as(c_int, 1014);
pub const SQLITE_DBCONFIG_ENABLE_VIEW = @as(c_int, 1015);
pub const SQLITE_DBCONFIG_LEGACY_FILE_FORMAT = @as(c_int, 1016);
pub const SQLITE_DBCONFIG_TRUSTED_SCHEMA = @as(c_int, 1017);
pub const SQLITE_DBCONFIG_STMT_SCANSTATUS = @as(c_int, 1018);
pub const SQLITE_DBCONFIG_REVERSE_SCANORDER = @as(c_int, 1019);
pub const SQLITE_DBCONFIG_ENABLE_ATTACH_CREATE = @as(c_int, 1020);
pub const SQLITE_DBCONFIG_ENABLE_ATTACH_WRITE = @as(c_int, 1021);
pub const SQLITE_DBCONFIG_ENABLE_COMMENTS = @as(c_int, 1022);
pub const SQLITE_DBCONFIG_MAX = @as(c_int, 1022);
pub const SQLITE_SETLK_BLOCK_ON_CONNECT = @as(c_int, 0x01);
pub const SQLITE_DENY = @as(c_int, 1);
pub const SQLITE_IGNORE = @as(c_int, 2);
pub const SQLITE_CREATE_INDEX = @as(c_int, 1);
pub const SQLITE_CREATE_TABLE = @as(c_int, 2);
pub const SQLITE_CREATE_TEMP_INDEX = @as(c_int, 3);
pub const SQLITE_CREATE_TEMP_TABLE = @as(c_int, 4);
pub const SQLITE_CREATE_TEMP_TRIGGER = @as(c_int, 5);
pub const SQLITE_CREATE_TEMP_VIEW = @as(c_int, 6);
pub const SQLITE_CREATE_TRIGGER = @as(c_int, 7);
pub const SQLITE_CREATE_VIEW = @as(c_int, 8);
pub const SQLITE_DELETE = @as(c_int, 9);
pub const SQLITE_DROP_INDEX = @as(c_int, 10);
pub const SQLITE_DROP_TABLE = @as(c_int, 11);
pub const SQLITE_DROP_TEMP_INDEX = @as(c_int, 12);
pub const SQLITE_DROP_TEMP_TABLE = @as(c_int, 13);
pub const SQLITE_DROP_TEMP_TRIGGER = @as(c_int, 14);
pub const SQLITE_DROP_TEMP_VIEW = @as(c_int, 15);
pub const SQLITE_DROP_TRIGGER = @as(c_int, 16);
pub const SQLITE_DROP_VIEW = @as(c_int, 17);
pub const SQLITE_INSERT = @as(c_int, 18);
pub const SQLITE_PRAGMA = @as(c_int, 19);
pub const SQLITE_READ = @as(c_int, 20);
pub const SQLITE_SELECT = @as(c_int, 21);
pub const SQLITE_TRANSACTION = @as(c_int, 22);
pub const SQLITE_UPDATE = @as(c_int, 23);
pub const SQLITE_ATTACH = @as(c_int, 24);
pub const SQLITE_DETACH = @as(c_int, 25);
pub const SQLITE_ALTER_TABLE = @as(c_int, 26);
pub const SQLITE_REINDEX = @as(c_int, 27);
pub const SQLITE_ANALYZE = @as(c_int, 28);
pub const SQLITE_CREATE_VTABLE = @as(c_int, 29);
pub const SQLITE_DROP_VTABLE = @as(c_int, 30);
pub const SQLITE_FUNCTION = @as(c_int, 31);
pub const SQLITE_SAVEPOINT = @as(c_int, 32);
pub const SQLITE_COPY = @as(c_int, 0);
pub const SQLITE_RECURSIVE = @as(c_int, 33);
pub const SQLITE_TRACE_STMT = @as(c_int, 0x01);
pub const SQLITE_TRACE_PROFILE = @as(c_int, 0x02);
pub const SQLITE_TRACE_ROW = @as(c_int, 0x04);
pub const SQLITE_TRACE_CLOSE = @as(c_int, 0x08);
pub const SQLITE_LIMIT_LENGTH = @as(c_int, 0);
pub const SQLITE_LIMIT_SQL_LENGTH = @as(c_int, 1);
pub const SQLITE_LIMIT_COLUMN = @as(c_int, 2);
pub const SQLITE_LIMIT_EXPR_DEPTH = @as(c_int, 3);
pub const SQLITE_LIMIT_COMPOUND_SELECT = @as(c_int, 4);
pub const SQLITE_LIMIT_VDBE_OP = @as(c_int, 5);
pub const SQLITE_LIMIT_FUNCTION_ARG = @as(c_int, 6);
pub const SQLITE_LIMIT_ATTACHED = @as(c_int, 7);
pub const SQLITE_LIMIT_LIKE_PATTERN_LENGTH = @as(c_int, 8);
pub const SQLITE_LIMIT_VARIABLE_NUMBER = @as(c_int, 9);
pub const SQLITE_LIMIT_TRIGGER_DEPTH = @as(c_int, 10);
pub const SQLITE_LIMIT_WORKER_THREADS = @as(c_int, 11);
pub const SQLITE_PREPARE_PERSISTENT = @as(c_int, 0x01);
pub const SQLITE_PREPARE_NORMALIZE = @as(c_int, 0x02);
pub const SQLITE_PREPARE_NO_VTAB = @as(c_int, 0x04);
pub const SQLITE_PREPARE_DONT_LOG = @as(c_int, 0x10);
pub const SQLITE_INTEGER = @as(c_int, 1);
pub const SQLITE_FLOAT = @as(c_int, 2);
pub const SQLITE_BLOB = @as(c_int, 4);
pub const SQLITE_NULL = @as(c_int, 5);
pub const SQLITE_TEXT = @as(c_int, 3);
pub const SQLITE3_TEXT = @as(c_int, 3);
pub const SQLITE_UTF8 = @as(c_int, 1);
pub const SQLITE_UTF16LE = @as(c_int, 2);
pub const SQLITE_UTF16BE = @as(c_int, 3);
pub const SQLITE_UTF16 = @as(c_int, 4);
pub const SQLITE_ANY = @as(c_int, 5);
pub const SQLITE_UTF16_ALIGNED = @as(c_int, 8);
pub const SQLITE_DETERMINISTIC = @as(c_int, 0x000000800);
pub const SQLITE_DIRECTONLY = __helpers.promoteIntLiteral(c_int, 0x000080000, .hex);
pub const SQLITE_SUBTYPE = __helpers.promoteIntLiteral(c_int, 0x000100000, .hex);
pub const SQLITE_INNOCUOUS = __helpers.promoteIntLiteral(c_int, 0x000200000, .hex);
pub const SQLITE_RESULT_SUBTYPE = __helpers.promoteIntLiteral(c_int, 0x001000000, .hex);
pub const SQLITE_SELFORDER1 = __helpers.promoteIntLiteral(c_int, 0x002000000, .hex);
pub const SQLITE_STATIC = __helpers.cast(sqlite3_destructor_type, @as(c_int, 0));
pub const SQLITE_TRANSIENT = __helpers.cast(sqlite3_destructor_type, -@as(c_int, 1));
pub const SQLITE_WIN32_DATA_DIRECTORY_TYPE = @as(c_int, 1);
pub const SQLITE_WIN32_TEMP_DIRECTORY_TYPE = @as(c_int, 2);
pub const SQLITE_TXN_NONE = @as(c_int, 0);
pub const SQLITE_TXN_READ = @as(c_int, 1);
pub const SQLITE_TXN_WRITE = @as(c_int, 2);
pub const SQLITE_INDEX_SCAN_UNIQUE = @as(c_int, 0x00000001);
pub const SQLITE_INDEX_SCAN_HEX = @as(c_int, 0x00000002);
pub const SQLITE_INDEX_CONSTRAINT_EQ = @as(c_int, 2);
pub const SQLITE_INDEX_CONSTRAINT_GT = @as(c_int, 4);
pub const SQLITE_INDEX_CONSTRAINT_LE = @as(c_int, 8);
pub const SQLITE_INDEX_CONSTRAINT_LT = @as(c_int, 16);
pub const SQLITE_INDEX_CONSTRAINT_GE = @as(c_int, 32);
pub const SQLITE_INDEX_CONSTRAINT_MATCH = @as(c_int, 64);
pub const SQLITE_INDEX_CONSTRAINT_LIKE = @as(c_int, 65);
pub const SQLITE_INDEX_CONSTRAINT_GLOB = @as(c_int, 66);
pub const SQLITE_INDEX_CONSTRAINT_REGEXP = @as(c_int, 67);
pub const SQLITE_INDEX_CONSTRAINT_NE = @as(c_int, 68);
pub const SQLITE_INDEX_CONSTRAINT_ISNOT = @as(c_int, 69);
pub const SQLITE_INDEX_CONSTRAINT_ISNOTNULL = @as(c_int, 70);
pub const SQLITE_INDEX_CONSTRAINT_ISNULL = @as(c_int, 71);
pub const SQLITE_INDEX_CONSTRAINT_IS = @as(c_int, 72);
pub const SQLITE_INDEX_CONSTRAINT_LIMIT = @as(c_int, 73);
pub const SQLITE_INDEX_CONSTRAINT_OFFSET = @as(c_int, 74);
pub const SQLITE_INDEX_CONSTRAINT_FUNCTION = @as(c_int, 150);
pub const SQLITE_MUTEX_FAST = @as(c_int, 0);
pub const SQLITE_MUTEX_RECURSIVE = @as(c_int, 1);
pub const SQLITE_MUTEX_STATIC_MAIN = @as(c_int, 2);
pub const SQLITE_MUTEX_STATIC_MEM = @as(c_int, 3);
pub const SQLITE_MUTEX_STATIC_MEM2 = @as(c_int, 4);
pub const SQLITE_MUTEX_STATIC_OPEN = @as(c_int, 4);
pub const SQLITE_MUTEX_STATIC_PRNG = @as(c_int, 5);
pub const SQLITE_MUTEX_STATIC_LRU = @as(c_int, 6);
pub const SQLITE_MUTEX_STATIC_LRU2 = @as(c_int, 7);
pub const SQLITE_MUTEX_STATIC_PMEM = @as(c_int, 7);
pub const SQLITE_MUTEX_STATIC_APP1 = @as(c_int, 8);
pub const SQLITE_MUTEX_STATIC_APP2 = @as(c_int, 9);
pub const SQLITE_MUTEX_STATIC_APP3 = @as(c_int, 10);
pub const SQLITE_MUTEX_STATIC_VFS1 = @as(c_int, 11);
pub const SQLITE_MUTEX_STATIC_VFS2 = @as(c_int, 12);
pub const SQLITE_MUTEX_STATIC_VFS3 = @as(c_int, 13);
pub const SQLITE_MUTEX_STATIC_MASTER = @as(c_int, 2);
pub const SQLITE_TESTCTRL_FIRST = @as(c_int, 5);
pub const SQLITE_TESTCTRL_PRNG_SAVE = @as(c_int, 5);
pub const SQLITE_TESTCTRL_PRNG_RESTORE = @as(c_int, 6);
pub const SQLITE_TESTCTRL_PRNG_RESET = @as(c_int, 7);
pub const SQLITE_TESTCTRL_FK_NO_ACTION = @as(c_int, 7);
pub const SQLITE_TESTCTRL_BITVEC_TEST = @as(c_int, 8);
pub const SQLITE_TESTCTRL_FAULT_INSTALL = @as(c_int, 9);
pub const SQLITE_TESTCTRL_BENIGN_MALLOC_HOOKS = @as(c_int, 10);
pub const SQLITE_TESTCTRL_PENDING_BYTE = @as(c_int, 11);
pub const SQLITE_TESTCTRL_ASSERT = @as(c_int, 12);
pub const SQLITE_TESTCTRL_ALWAYS = @as(c_int, 13);
pub const SQLITE_TESTCTRL_RESERVE = @as(c_int, 14);
pub const SQLITE_TESTCTRL_JSON_SELFCHECK = @as(c_int, 14);
pub const SQLITE_TESTCTRL_OPTIMIZATIONS = @as(c_int, 15);
pub const SQLITE_TESTCTRL_ISKEYWORD = @as(c_int, 16);
pub const SQLITE_TESTCTRL_GETOPT = @as(c_int, 16);
pub const SQLITE_TESTCTRL_SCRATCHMALLOC = @as(c_int, 17);
pub const SQLITE_TESTCTRL_INTERNAL_FUNCTIONS = @as(c_int, 17);
pub const SQLITE_TESTCTRL_LOCALTIME_FAULT = @as(c_int, 18);
pub const SQLITE_TESTCTRL_EXPLAIN_STMT = @as(c_int, 19);
pub const SQLITE_TESTCTRL_ONCE_RESET_THRESHOLD = @as(c_int, 19);
pub const SQLITE_TESTCTRL_NEVER_CORRUPT = @as(c_int, 20);
pub const SQLITE_TESTCTRL_VDBE_COVERAGE = @as(c_int, 21);
pub const SQLITE_TESTCTRL_BYTEORDER = @as(c_int, 22);
pub const SQLITE_TESTCTRL_ISINIT = @as(c_int, 23);
pub const SQLITE_TESTCTRL_SORTER_MMAP = @as(c_int, 24);
pub const SQLITE_TESTCTRL_IMPOSTER = @as(c_int, 25);
pub const SQLITE_TESTCTRL_PARSER_COVERAGE = @as(c_int, 26);
pub const SQLITE_TESTCTRL_RESULT_INTREAL = @as(c_int, 27);
pub const SQLITE_TESTCTRL_PRNG_SEED = @as(c_int, 28);
pub const SQLITE_TESTCTRL_EXTRA_SCHEMA_CHECKS = @as(c_int, 29);
pub const SQLITE_TESTCTRL_SEEK_COUNT = @as(c_int, 30);
pub const SQLITE_TESTCTRL_TRACEFLAGS = @as(c_int, 31);
pub const SQLITE_TESTCTRL_TUNE = @as(c_int, 32);
pub const SQLITE_TESTCTRL_LOGEST = @as(c_int, 33);
pub const SQLITE_TESTCTRL_USELONGDOUBLE = @as(c_int, 34);
pub const SQLITE_TESTCTRL_LAST = @as(c_int, 34);
pub const SQLITE_STATUS_MEMORY_USED = @as(c_int, 0);
pub const SQLITE_STATUS_PAGECACHE_USED = @as(c_int, 1);
pub const SQLITE_STATUS_PAGECACHE_OVERFLOW = @as(c_int, 2);
pub const SQLITE_STATUS_SCRATCH_USED = @as(c_int, 3);
pub const SQLITE_STATUS_SCRATCH_OVERFLOW = @as(c_int, 4);
pub const SQLITE_STATUS_MALLOC_SIZE = @as(c_int, 5);
pub const SQLITE_STATUS_PARSER_STACK = @as(c_int, 6);
pub const SQLITE_STATUS_PAGECACHE_SIZE = @as(c_int, 7);
pub const SQLITE_STATUS_SCRATCH_SIZE = @as(c_int, 8);
pub const SQLITE_STATUS_MALLOC_COUNT = @as(c_int, 9);
pub const SQLITE_DBSTATUS_LOOKASIDE_USED = @as(c_int, 0);
pub const SQLITE_DBSTATUS_CACHE_USED = @as(c_int, 1);
pub const SQLITE_DBSTATUS_SCHEMA_USED = @as(c_int, 2);
pub const SQLITE_DBSTATUS_STMT_USED = @as(c_int, 3);
pub const SQLITE_DBSTATUS_LOOKASIDE_HIT = @as(c_int, 4);
pub const SQLITE_DBSTATUS_LOOKASIDE_MISS_SIZE = @as(c_int, 5);
pub const SQLITE_DBSTATUS_LOOKASIDE_MISS_FULL = @as(c_int, 6);
pub const SQLITE_DBSTATUS_CACHE_HIT = @as(c_int, 7);
pub const SQLITE_DBSTATUS_CACHE_MISS = @as(c_int, 8);
pub const SQLITE_DBSTATUS_CACHE_WRITE = @as(c_int, 9);
pub const SQLITE_DBSTATUS_DEFERRED_FKS = @as(c_int, 10);
pub const SQLITE_DBSTATUS_CACHE_USED_SHARED = @as(c_int, 11);
pub const SQLITE_DBSTATUS_CACHE_SPILL = @as(c_int, 12);
pub const SQLITE_DBSTATUS_MAX = @as(c_int, 12);
pub const SQLITE_STMTSTATUS_FULLSCAN_STEP = @as(c_int, 1);
pub const SQLITE_STMTSTATUS_SORT = @as(c_int, 2);
pub const SQLITE_STMTSTATUS_AUTOINDEX = @as(c_int, 3);
pub const SQLITE_STMTSTATUS_VM_STEP = @as(c_int, 4);
pub const SQLITE_STMTSTATUS_REPREPARE = @as(c_int, 5);
pub const SQLITE_STMTSTATUS_RUN = @as(c_int, 6);
pub const SQLITE_STMTSTATUS_FILTER_MISS = @as(c_int, 7);
pub const SQLITE_STMTSTATUS_FILTER_HIT = @as(c_int, 8);
pub const SQLITE_STMTSTATUS_MEMUSED = @as(c_int, 99);
pub const SQLITE_CHECKPOINT_PASSIVE = @as(c_int, 0);
pub const SQLITE_CHECKPOINT_FULL = @as(c_int, 1);
pub const SQLITE_CHECKPOINT_RESTART = @as(c_int, 2);
pub const SQLITE_CHECKPOINT_TRUNCATE = @as(c_int, 3);
pub const SQLITE_VTAB_CONSTRAINT_SUPPORT = @as(c_int, 1);
pub const SQLITE_VTAB_INNOCUOUS = @as(c_int, 2);
pub const SQLITE_VTAB_DIRECTONLY = @as(c_int, 3);
pub const SQLITE_VTAB_USES_ALL_SCHEMAS = @as(c_int, 4);
pub const SQLITE_ROLLBACK = @as(c_int, 1);
pub const SQLITE_FAIL = @as(c_int, 3);
pub const SQLITE_REPLACE = @as(c_int, 5);
pub const SQLITE_SCANSTAT_NLOOP = @as(c_int, 0);
pub const SQLITE_SCANSTAT_NVISIT = @as(c_int, 1);
pub const SQLITE_SCANSTAT_EST = @as(c_int, 2);
pub const SQLITE_SCANSTAT_NAME = @as(c_int, 3);
pub const SQLITE_SCANSTAT_EXPLAIN = @as(c_int, 4);
pub const SQLITE_SCANSTAT_SELECTID = @as(c_int, 5);
pub const SQLITE_SCANSTAT_PARENTID = @as(c_int, 6);
pub const SQLITE_SCANSTAT_NCYCLE = @as(c_int, 7);
pub const SQLITE_SCANSTAT_COMPLEX = @as(c_int, 0x0001);
pub const SQLITE_SERIALIZE_NOCOPY = @as(c_int, 0x001);
pub const SQLITE_DESERIALIZE_FREEONCLOSE = @as(c_int, 1);
pub const SQLITE_DESERIALIZE_RESIZEABLE = @as(c_int, 2);
pub const SQLITE_DESERIALIZE_READONLY = @as(c_int, 4);
pub const _SQLITE3RTREE_H_ = "";
pub const NOT_WITHIN = @as(c_int, 0);
pub const PARTLY_WITHIN = @as(c_int, 1);
pub const FULLY_WITHIN = @as(c_int, 2);
pub const _FTS5_H = "";
pub const FTS5_TOKENIZE_QUERY = @as(c_int, 0x0001);
pub const FTS5_TOKENIZE_PREFIX = @as(c_int, 0x0002);
pub const FTS5_TOKENIZE_DOCUMENT = @as(c_int, 0x0004);
pub const FTS5_TOKENIZE_AUX = @as(c_int, 0x0008);
pub const FTS5_TOKEN_COLOCATED = @as(c_int, 0x0001);
