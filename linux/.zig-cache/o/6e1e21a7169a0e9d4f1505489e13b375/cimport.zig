const __root = @This();
pub const __builtin = @import("std").zig.c_translation.builtins;
pub const __helpers = @import("std").zig.c_translation.helpers;

pub const dbus_int64_t = c_long;
pub const dbus_uint64_t = c_ulong;
pub const dbus_int32_t = c_int;
pub const dbus_uint32_t = c_uint;
pub const dbus_int16_t = c_short;
pub const dbus_uint16_t = c_ushort;
pub const ptrdiff_t = c_long;
pub const wchar_t = c_int;
pub const max_align_t = extern struct {
    __aro_max_align_ll: c_longlong = 0,
    __aro_max_align_ld: c_longdouble = 0,
};
pub const dbus_unichar_t = dbus_uint32_t;
pub const dbus_bool_t = dbus_uint32_t;
pub const DBus8ByteStruct = extern struct {
    first32: dbus_uint32_t = 0,
    second32: dbus_uint32_t = 0,
};
pub const DBusBasicValue = extern union {
    bytes: [8]u8,
    i16: dbus_int16_t,
    u16: dbus_uint16_t,
    i32: dbus_int32_t,
    u32: dbus_uint32_t,
    bool_val: dbus_bool_t,
    i64: dbus_int64_t,
    u64: dbus_uint64_t,
    eight: DBus8ByteStruct,
    dbl: f64,
    byt: u8,
    str: [*c]u8,
    fd: c_int,
}; // /usr/include/dbus-1.0/dbus/dbus-errors.h:55:16: warning: struct demoted to opaque type - has bitfield
pub const struct_DBusError = opaque {
    pub const dbus_error_init = __root.dbus_error_init;
    pub const dbus_error_free = __root.dbus_error_free;
    pub const dbus_set_error = __root.dbus_set_error;
    pub const dbus_set_error_const = __root.dbus_set_error_const;
    pub const dbus_move_error = __root.dbus_move_error;
    pub const dbus_error_has_name = __root.dbus_error_has_name;
    pub const dbus_error_is_set = __root.dbus_error_is_set;
    pub const dbus_set_error_from_message = __root.dbus_set_error_from_message;
    pub const dbus_try_get_local_machine_id = __root.dbus_try_get_local_machine_id;
    pub const init = __root.dbus_error_init;
    pub const free = __root.dbus_error_free;
    pub const @"error" = __root.dbus_set_error;
    pub const @"const" = __root.dbus_set_error_const;
    pub const name = __root.dbus_error_has_name;
    pub const set = __root.dbus_error_is_set;
    pub const message = __root.dbus_set_error_from_message;
    pub const id = __root.dbus_try_get_local_machine_id;
};
pub const DBusError = struct_DBusError;
pub extern fn dbus_error_init(@"error": ?*DBusError) void;
pub extern fn dbus_error_free(@"error": ?*DBusError) void;
pub extern fn dbus_set_error(@"error": ?*DBusError, name: [*c]const u8, message: [*c]const u8, ...) void;
pub extern fn dbus_set_error_const(@"error": ?*DBusError, name: [*c]const u8, message: [*c]const u8) void;
pub extern fn dbus_move_error(src: ?*DBusError, dest: ?*DBusError) void;
pub extern fn dbus_error_has_name(@"error": ?*const DBusError, name: [*c]const u8) dbus_bool_t;
pub extern fn dbus_error_is_set(@"error": ?*const DBusError) dbus_bool_t;
pub const struct_DBusAddressEntry = opaque {
    pub const dbus_address_entry_get_value = __root.dbus_address_entry_get_value;
    pub const dbus_address_entry_get_method = __root.dbus_address_entry_get_method;
    pub const value = __root.dbus_address_entry_get_value;
    pub const method = __root.dbus_address_entry_get_method;
};
pub const DBusAddressEntry = struct_DBusAddressEntry;
pub extern fn dbus_parse_address(address: [*c]const u8, entry_result: [*c][*c]?*DBusAddressEntry, array_len: [*c]c_int, @"error": ?*DBusError) dbus_bool_t;
pub extern fn dbus_address_entry_get_value(entry: ?*DBusAddressEntry, key: [*c]const u8) [*c]const u8;
pub extern fn dbus_address_entry_get_method(entry: ?*DBusAddressEntry) [*c]const u8;
pub extern fn dbus_address_entries_free(entries: [*c]?*DBusAddressEntry) void;
pub extern fn dbus_address_escape_value(value: [*c]const u8) [*c]u8;
pub extern fn dbus_address_unescape_value(value: [*c]const u8, @"error": ?*DBusError) [*c]u8;
pub fn dbus_clear_address_entries(arg_pointer_to_entries: [*c][*c]?*DBusAddressEntry) callconv(.c) void {
    var pointer_to_entries = arg_pointer_to_entries;
    _ = &pointer_to_entries;
    while (true) {
        var _pp: [*c][*c]?*DBusAddressEntry = pointer_to_entries;
        _ = &_pp;
        var _value: [*c]?*DBusAddressEntry = _pp.*;
        _ = &_value;
        _pp.* = null;
        if (@as(?*anyopaque, @ptrCast(@alignCast(_value))) != @as(?*anyopaque, null)) {
            dbus_address_entries_free(_value);
        }
        if (!false) break;
    }
}
pub extern fn dbus_malloc(bytes: usize) ?*anyopaque;
pub extern fn dbus_malloc0(bytes: usize) ?*anyopaque;
pub extern fn dbus_realloc(memory: ?*anyopaque, bytes: usize) ?*anyopaque;
pub extern fn dbus_free(memory: ?*anyopaque) void;
pub extern fn dbus_free_string_array(str_array: [*c][*c]u8) void;
pub const DBusFreeFunction = ?*const fn (memory: ?*anyopaque) callconv(.c) void;
pub extern fn dbus_shutdown() void;
pub const struct___va_list_tag_1 = extern struct {
    unnamed_0: c_uint = 0,
    unnamed_1: c_uint = 0,
    unnamed_2: ?*anyopaque = null,
    unnamed_3: ?*anyopaque = null,
};
pub const __builtin_va_list = [1]struct___va_list_tag_1;
pub const va_list = __builtin_va_list;
pub const __gnuc_va_list = __builtin_va_list;
pub const struct_DBusMessage = opaque {
    pub const dbus_message_new_method_return = __root.dbus_message_new_method_return;
    pub const dbus_message_new_error = __root.dbus_message_new_error;
    pub const dbus_message_new_error_printf = __root.dbus_message_new_error_printf;
    pub const dbus_message_copy = __root.dbus_message_copy;
    pub const dbus_message_ref = __root.dbus_message_ref;
    pub const dbus_message_unref = __root.dbus_message_unref;
    pub const dbus_message_get_type = __root.dbus_message_get_type;
    pub const dbus_message_set_path = __root.dbus_message_set_path;
    pub const dbus_message_get_path = __root.dbus_message_get_path;
    pub const dbus_message_has_path = __root.dbus_message_has_path;
    pub const dbus_message_set_interface = __root.dbus_message_set_interface;
    pub const dbus_message_get_interface = __root.dbus_message_get_interface;
    pub const dbus_message_has_interface = __root.dbus_message_has_interface;
    pub const dbus_message_set_member = __root.dbus_message_set_member;
    pub const dbus_message_get_member = __root.dbus_message_get_member;
    pub const dbus_message_has_member = __root.dbus_message_has_member;
    pub const dbus_message_set_error_name = __root.dbus_message_set_error_name;
    pub const dbus_message_get_error_name = __root.dbus_message_get_error_name;
    pub const dbus_message_set_destination = __root.dbus_message_set_destination;
    pub const dbus_message_get_destination = __root.dbus_message_get_destination;
    pub const dbus_message_set_sender = __root.dbus_message_set_sender;
    pub const dbus_message_get_sender = __root.dbus_message_get_sender;
    pub const dbus_message_get_signature = __root.dbus_message_get_signature;
    pub const dbus_message_set_no_reply = __root.dbus_message_set_no_reply;
    pub const dbus_message_get_no_reply = __root.dbus_message_get_no_reply;
    pub const dbus_message_is_method_call = __root.dbus_message_is_method_call;
    pub const dbus_message_is_signal = __root.dbus_message_is_signal;
    pub const dbus_message_is_error = __root.dbus_message_is_error;
    pub const dbus_message_has_destination = __root.dbus_message_has_destination;
    pub const dbus_message_has_sender = __root.dbus_message_has_sender;
    pub const dbus_message_has_signature = __root.dbus_message_has_signature;
    pub const dbus_message_get_serial = __root.dbus_message_get_serial;
    pub const dbus_message_set_serial = __root.dbus_message_set_serial;
    pub const dbus_message_set_reply_serial = __root.dbus_message_set_reply_serial;
    pub const dbus_message_get_reply_serial = __root.dbus_message_get_reply_serial;
    pub const dbus_message_set_auto_start = __root.dbus_message_set_auto_start;
    pub const dbus_message_get_auto_start = __root.dbus_message_get_auto_start;
    pub const dbus_message_get_path_decomposed = __root.dbus_message_get_path_decomposed;
    pub const dbus_message_get_container_instance = __root.dbus_message_get_container_instance;
    pub const dbus_message_set_container_instance = __root.dbus_message_set_container_instance;
    pub const dbus_message_append_args = __root.dbus_message_append_args;
    pub const dbus_message_append_args_valist = __root.dbus_message_append_args_valist;
    pub const dbus_message_get_args = __root.dbus_message_get_args;
    pub const dbus_message_get_args_valist = __root.dbus_message_get_args_valist;
    pub const dbus_message_contains_unix_fds = __root.dbus_message_contains_unix_fds;
    pub const dbus_message_iter_init = __root.dbus_message_iter_init;
    pub const dbus_message_iter_init_append = __root.dbus_message_iter_init_append;
    pub const dbus_message_lock = __root.dbus_message_lock;
    pub const dbus_message_set_data = __root.dbus_message_set_data;
    pub const dbus_message_get_data = __root.dbus_message_get_data;
    pub const dbus_message_marshal = __root.dbus_message_marshal;
    pub const dbus_message_set_allow_interactive_authorization = __root.dbus_message_set_allow_interactive_authorization;
    pub const dbus_message_get_allow_interactive_authorization = __root.dbus_message_get_allow_interactive_authorization;
    pub const @"return" = __root.dbus_message_new_method_return;
    pub const @"error" = __root.dbus_message_new_error;
    pub const printf = __root.dbus_message_new_error_printf;
    pub const copy = __root.dbus_message_copy;
    pub const ref = __root.dbus_message_ref;
    pub const unref = __root.dbus_message_unref;
    pub const @"type" = __root.dbus_message_get_type;
    pub const path = __root.dbus_message_set_path;
    pub const interface = __root.dbus_message_set_interface;
    pub const member = __root.dbus_message_set_member;
    pub const name = __root.dbus_message_set_error_name;
    pub const destination = __root.dbus_message_set_destination;
    pub const sender = __root.dbus_message_set_sender;
    pub const signature = __root.dbus_message_get_signature;
    pub const reply = __root.dbus_message_set_no_reply;
    pub const call = __root.dbus_message_is_method_call;
    pub const signal = __root.dbus_message_is_signal;
    pub const serial = __root.dbus_message_get_serial;
    pub const start = __root.dbus_message_set_auto_start;
    pub const decomposed = __root.dbus_message_get_path_decomposed;
    pub const instance = __root.dbus_message_get_container_instance;
    pub const args = __root.dbus_message_append_args;
    pub const valist = __root.dbus_message_append_args_valist;
    pub const fds = __root.dbus_message_contains_unix_fds;
    pub const init = __root.dbus_message_iter_init;
    pub const append = __root.dbus_message_iter_init_append;
    pub const lock = __root.dbus_message_lock;
    pub const data = __root.dbus_message_set_data;
    pub const marshal = __root.dbus_message_marshal;
    pub const authorization = __root.dbus_message_set_allow_interactive_authorization;
};
pub const DBusMessage = struct_DBusMessage;
pub const struct_DBusMessageIter = extern struct {
    dummy1: ?*anyopaque = null,
    dummy2: ?*anyopaque = null,
    dummy3: dbus_uint32_t = 0,
    dummy4: c_int = 0,
    dummy5: c_int = 0,
    dummy6: c_int = 0,
    dummy7: c_int = 0,
    dummy8: c_int = 0,
    dummy9: c_int = 0,
    dummy10: c_int = 0,
    dummy11: c_int = 0,
    pad1: c_int = 0,
    pad2: ?*anyopaque = null,
    pad3: ?*anyopaque = null,
    pub const dbus_message_iter_init_closed = __root.dbus_message_iter_init_closed;
    pub const dbus_message_iter_has_next = __root.dbus_message_iter_has_next;
    pub const dbus_message_iter_next = __root.dbus_message_iter_next;
    pub const dbus_message_iter_get_signature = __root.dbus_message_iter_get_signature;
    pub const dbus_message_iter_get_arg_type = __root.dbus_message_iter_get_arg_type;
    pub const dbus_message_iter_get_element_type = __root.dbus_message_iter_get_element_type;
    pub const dbus_message_iter_recurse = __root.dbus_message_iter_recurse;
    pub const dbus_message_iter_get_basic = __root.dbus_message_iter_get_basic;
    pub const dbus_message_iter_get_element_count = __root.dbus_message_iter_get_element_count;
    pub const dbus_message_iter_get_array_len = __root.dbus_message_iter_get_array_len;
    pub const dbus_message_iter_get_fixed_array = __root.dbus_message_iter_get_fixed_array;
    pub const dbus_message_iter_append_basic = __root.dbus_message_iter_append_basic;
    pub const dbus_message_iter_append_fixed_array = __root.dbus_message_iter_append_fixed_array;
    pub const dbus_message_iter_open_container = __root.dbus_message_iter_open_container;
    pub const dbus_message_iter_close_container = __root.dbus_message_iter_close_container;
    pub const dbus_message_iter_abandon_container = __root.dbus_message_iter_abandon_container;
    pub const dbus_message_iter_abandon_container_if_open = __root.dbus_message_iter_abandon_container_if_open;
    pub const closed = __root.dbus_message_iter_init_closed;
    pub const next = __root.dbus_message_iter_has_next;
    pub const signature = __root.dbus_message_iter_get_signature;
    pub const @"type" = __root.dbus_message_iter_get_arg_type;
    pub const recurse = __root.dbus_message_iter_recurse;
    pub const basic = __root.dbus_message_iter_get_basic;
    pub const count = __root.dbus_message_iter_get_element_count;
    pub const len = __root.dbus_message_iter_get_array_len;
    pub const array = __root.dbus_message_iter_get_fixed_array;
    pub const container = __root.dbus_message_iter_open_container;
    pub const open = __root.dbus_message_iter_abandon_container_if_open;
};
pub const DBusMessageIter = struct_DBusMessageIter;
pub extern fn dbus_message_new(message_type: c_int) ?*DBusMessage;
pub extern fn dbus_message_new_method_call(bus_name: [*c]const u8, path: [*c]const u8, iface: [*c]const u8, method: [*c]const u8) ?*DBusMessage;
pub extern fn dbus_message_new_method_return(method_call: ?*DBusMessage) ?*DBusMessage;
pub extern fn dbus_message_new_signal(path: [*c]const u8, iface: [*c]const u8, name: [*c]const u8) ?*DBusMessage;
pub extern fn dbus_message_new_error(reply_to: ?*DBusMessage, error_name: [*c]const u8, error_message: [*c]const u8) ?*DBusMessage;
pub extern fn dbus_message_new_error_printf(reply_to: ?*DBusMessage, error_name: [*c]const u8, error_format: [*c]const u8, ...) ?*DBusMessage;
pub extern fn dbus_message_copy(message: ?*const DBusMessage) ?*DBusMessage;
pub extern fn dbus_message_ref(message: ?*DBusMessage) ?*DBusMessage;
pub extern fn dbus_message_unref(message: ?*DBusMessage) void;
pub extern fn dbus_message_get_type(message: ?*DBusMessage) c_int;
pub extern fn dbus_message_set_path(message: ?*DBusMessage, object_path: [*c]const u8) dbus_bool_t;
pub extern fn dbus_message_get_path(message: ?*DBusMessage) [*c]const u8;
pub extern fn dbus_message_has_path(message: ?*DBusMessage, object_path: [*c]const u8) dbus_bool_t;
pub extern fn dbus_message_set_interface(message: ?*DBusMessage, iface: [*c]const u8) dbus_bool_t;
pub extern fn dbus_message_get_interface(message: ?*DBusMessage) [*c]const u8;
pub extern fn dbus_message_has_interface(message: ?*DBusMessage, iface: [*c]const u8) dbus_bool_t;
pub extern fn dbus_message_set_member(message: ?*DBusMessage, member: [*c]const u8) dbus_bool_t;
pub extern fn dbus_message_get_member(message: ?*DBusMessage) [*c]const u8;
pub extern fn dbus_message_has_member(message: ?*DBusMessage, member: [*c]const u8) dbus_bool_t;
pub extern fn dbus_message_set_error_name(message: ?*DBusMessage, name: [*c]const u8) dbus_bool_t;
pub extern fn dbus_message_get_error_name(message: ?*DBusMessage) [*c]const u8;
pub extern fn dbus_message_set_destination(message: ?*DBusMessage, destination: [*c]const u8) dbus_bool_t;
pub extern fn dbus_message_get_destination(message: ?*DBusMessage) [*c]const u8;
pub extern fn dbus_message_set_sender(message: ?*DBusMessage, sender: [*c]const u8) dbus_bool_t;
pub extern fn dbus_message_get_sender(message: ?*DBusMessage) [*c]const u8;
pub extern fn dbus_message_get_signature(message: ?*DBusMessage) [*c]const u8;
pub extern fn dbus_message_set_no_reply(message: ?*DBusMessage, no_reply: dbus_bool_t) void;
pub extern fn dbus_message_get_no_reply(message: ?*DBusMessage) dbus_bool_t;
pub extern fn dbus_message_is_method_call(message: ?*DBusMessage, iface: [*c]const u8, method: [*c]const u8) dbus_bool_t;
pub extern fn dbus_message_is_signal(message: ?*DBusMessage, iface: [*c]const u8, signal_name: [*c]const u8) dbus_bool_t;
pub extern fn dbus_message_is_error(message: ?*DBusMessage, error_name: [*c]const u8) dbus_bool_t;
pub extern fn dbus_message_has_destination(message: ?*DBusMessage, bus_name: [*c]const u8) dbus_bool_t;
pub extern fn dbus_message_has_sender(message: ?*DBusMessage, unique_bus_name: [*c]const u8) dbus_bool_t;
pub extern fn dbus_message_has_signature(message: ?*DBusMessage, signature: [*c]const u8) dbus_bool_t;
pub extern fn dbus_message_get_serial(message: ?*DBusMessage) dbus_uint32_t;
pub extern fn dbus_message_set_serial(message: ?*DBusMessage, serial: dbus_uint32_t) void;
pub extern fn dbus_message_set_reply_serial(message: ?*DBusMessage, reply_serial: dbus_uint32_t) dbus_bool_t;
pub extern fn dbus_message_get_reply_serial(message: ?*DBusMessage) dbus_uint32_t;
pub extern fn dbus_message_set_auto_start(message: ?*DBusMessage, auto_start: dbus_bool_t) void;
pub extern fn dbus_message_get_auto_start(message: ?*DBusMessage) dbus_bool_t;
pub extern fn dbus_message_get_path_decomposed(message: ?*DBusMessage, path: [*c][*c][*c]u8) dbus_bool_t;
pub extern fn dbus_message_get_container_instance(message: ?*DBusMessage) [*c]const u8;
pub extern fn dbus_message_set_container_instance(message: ?*DBusMessage, object_path: [*c]const u8) dbus_bool_t;
pub extern fn dbus_message_append_args(message: ?*DBusMessage, first_arg_type: c_int, ...) dbus_bool_t;
pub extern fn dbus_message_append_args_valist(message: ?*DBusMessage, first_arg_type: c_int, var_args: [*c]struct___va_list_tag_1) dbus_bool_t;
pub extern fn dbus_message_get_args(message: ?*DBusMessage, @"error": ?*DBusError, first_arg_type: c_int, ...) dbus_bool_t;
pub extern fn dbus_message_get_args_valist(message: ?*DBusMessage, @"error": ?*DBusError, first_arg_type: c_int, var_args: [*c]struct___va_list_tag_1) dbus_bool_t;
pub extern fn dbus_message_contains_unix_fds(message: ?*DBusMessage) dbus_bool_t;
pub extern fn dbus_message_iter_init_closed(iter: [*c]DBusMessageIter) void;
pub extern fn dbus_message_iter_init(message: ?*DBusMessage, iter: [*c]DBusMessageIter) dbus_bool_t;
pub extern fn dbus_message_iter_has_next(iter: [*c]DBusMessageIter) dbus_bool_t;
pub extern fn dbus_message_iter_next(iter: [*c]DBusMessageIter) dbus_bool_t;
pub extern fn dbus_message_iter_get_signature(iter: [*c]DBusMessageIter) [*c]u8;
pub extern fn dbus_message_iter_get_arg_type(iter: [*c]DBusMessageIter) c_int;
pub extern fn dbus_message_iter_get_element_type(iter: [*c]DBusMessageIter) c_int;
pub extern fn dbus_message_iter_recurse(iter: [*c]DBusMessageIter, sub: [*c]DBusMessageIter) void;
pub extern fn dbus_message_iter_get_basic(iter: [*c]DBusMessageIter, value: ?*anyopaque) void;
pub extern fn dbus_message_iter_get_element_count(iter: [*c]DBusMessageIter) c_int;
pub extern fn dbus_message_iter_get_array_len(iter: [*c]DBusMessageIter) c_int;
pub extern fn dbus_message_iter_get_fixed_array(iter: [*c]DBusMessageIter, value: ?*anyopaque, n_elements: [*c]c_int) void;
pub extern fn dbus_message_iter_init_append(message: ?*DBusMessage, iter: [*c]DBusMessageIter) void;
pub extern fn dbus_message_iter_append_basic(iter: [*c]DBusMessageIter, @"type": c_int, value: ?*const anyopaque) dbus_bool_t;
pub extern fn dbus_message_iter_append_fixed_array(iter: [*c]DBusMessageIter, element_type: c_int, value: ?*const anyopaque, n_elements: c_int) dbus_bool_t;
pub extern fn dbus_message_iter_open_container(iter: [*c]DBusMessageIter, @"type": c_int, contained_signature: [*c]const u8, sub: [*c]DBusMessageIter) dbus_bool_t;
pub extern fn dbus_message_iter_close_container(iter: [*c]DBusMessageIter, sub: [*c]DBusMessageIter) dbus_bool_t;
pub extern fn dbus_message_iter_abandon_container(iter: [*c]DBusMessageIter, sub: [*c]DBusMessageIter) void;
pub extern fn dbus_message_iter_abandon_container_if_open(iter: [*c]DBusMessageIter, sub: [*c]DBusMessageIter) void;
pub extern fn dbus_message_lock(message: ?*DBusMessage) void;
pub extern fn dbus_set_error_from_message(@"error": ?*DBusError, message: ?*DBusMessage) dbus_bool_t;
pub extern fn dbus_message_allocate_data_slot(slot_p: [*c]dbus_int32_t) dbus_bool_t;
pub extern fn dbus_message_free_data_slot(slot_p: [*c]dbus_int32_t) void;
pub extern fn dbus_message_set_data(message: ?*DBusMessage, slot: dbus_int32_t, data: ?*anyopaque, free_data_func: DBusFreeFunction) dbus_bool_t;
pub extern fn dbus_message_get_data(message: ?*DBusMessage, slot: dbus_int32_t) ?*anyopaque;
pub extern fn dbus_message_type_from_string(type_str: [*c]const u8) c_int;
pub extern fn dbus_message_type_to_string(@"type": c_int) [*c]const u8;
pub extern fn dbus_message_marshal(msg: ?*DBusMessage, marshalled_data_p: [*c][*c]u8, len_p: [*c]c_int) dbus_bool_t;
pub extern fn dbus_message_demarshal(str: [*c]const u8, len: c_int, @"error": ?*DBusError) ?*DBusMessage;
pub extern fn dbus_message_demarshal_bytes_needed(str: [*c]const u8, len: c_int) c_int;
pub extern fn dbus_message_set_allow_interactive_authorization(message: ?*DBusMessage, allow: dbus_bool_t) void;
pub extern fn dbus_message_get_allow_interactive_authorization(message: ?*DBusMessage) dbus_bool_t;
pub fn dbus_clear_message(arg_pointer_to_message: [*c]?*DBusMessage) callconv(.c) void {
    var pointer_to_message = arg_pointer_to_message;
    _ = &pointer_to_message;
    while (true) {
        var _pp: [*c]?*DBusMessage = pointer_to_message;
        _ = &_pp;
        var _value: ?*DBusMessage = _pp.*;
        _ = &_value;
        _pp.* = null;
        if (@as(?*anyopaque, @ptrCast(@alignCast(_value))) != @as(?*anyopaque, null)) {
            dbus_message_unref(_value);
        }
        if (!false) break;
    }
}
pub const DBUS_BUS_SESSION: c_int = 0;
pub const DBUS_BUS_SYSTEM: c_int = 1;
pub const DBUS_BUS_STARTER: c_int = 2;
pub const DBusBusType = c_uint;
pub const DBUS_HANDLER_RESULT_HANDLED: c_int = 0;
pub const DBUS_HANDLER_RESULT_NOT_YET_HANDLED: c_int = 1;
pub const DBUS_HANDLER_RESULT_NEED_MEMORY: c_int = 2;
pub const DBusHandlerResult = c_uint;
pub const struct_DBusWatch = opaque {
    pub const dbus_watch_get_fd = __root.dbus_watch_get_fd;
    pub const dbus_watch_get_unix_fd = __root.dbus_watch_get_unix_fd;
    pub const dbus_watch_get_socket = __root.dbus_watch_get_socket;
    pub const dbus_watch_get_flags = __root.dbus_watch_get_flags;
    pub const dbus_watch_get_data = __root.dbus_watch_get_data;
    pub const dbus_watch_set_data = __root.dbus_watch_set_data;
    pub const dbus_watch_handle = __root.dbus_watch_handle;
    pub const dbus_watch_get_enabled = __root.dbus_watch_get_enabled;
    pub const fd = __root.dbus_watch_get_fd;
    pub const socket = __root.dbus_watch_get_socket;
    pub const flags = __root.dbus_watch_get_flags;
    pub const data = __root.dbus_watch_get_data;
    pub const handle = __root.dbus_watch_handle;
    pub const enabled = __root.dbus_watch_get_enabled;
};
pub const DBusWatch = struct_DBusWatch;
pub const struct_DBusTimeout = opaque {
    pub const dbus_timeout_get_interval = __root.dbus_timeout_get_interval;
    pub const dbus_timeout_get_data = __root.dbus_timeout_get_data;
    pub const dbus_timeout_set_data = __root.dbus_timeout_set_data;
    pub const dbus_timeout_handle = __root.dbus_timeout_handle;
    pub const dbus_timeout_get_enabled = __root.dbus_timeout_get_enabled;
    pub const interval = __root.dbus_timeout_get_interval;
    pub const data = __root.dbus_timeout_get_data;
    pub const handle = __root.dbus_timeout_handle;
    pub const enabled = __root.dbus_timeout_get_enabled;
};
pub const DBusTimeout = struct_DBusTimeout;
pub const struct_DBusPreallocatedSend = opaque {};
pub const DBusPreallocatedSend = struct_DBusPreallocatedSend;
pub const struct_DBusPendingCall = opaque {
    pub const dbus_pending_call_ref = __root.dbus_pending_call_ref;
    pub const dbus_pending_call_unref = __root.dbus_pending_call_unref;
    pub const dbus_pending_call_set_notify = __root.dbus_pending_call_set_notify;
    pub const dbus_pending_call_cancel = __root.dbus_pending_call_cancel;
    pub const dbus_pending_call_get_completed = __root.dbus_pending_call_get_completed;
    pub const dbus_pending_call_steal_reply = __root.dbus_pending_call_steal_reply;
    pub const dbus_pending_call_block = __root.dbus_pending_call_block;
    pub const dbus_pending_call_set_data = __root.dbus_pending_call_set_data;
    pub const dbus_pending_call_get_data = __root.dbus_pending_call_get_data;
    pub const ref = __root.dbus_pending_call_ref;
    pub const unref = __root.dbus_pending_call_unref;
    pub const notify = __root.dbus_pending_call_set_notify;
    pub const cancel = __root.dbus_pending_call_cancel;
    pub const completed = __root.dbus_pending_call_get_completed;
    pub const reply = __root.dbus_pending_call_steal_reply;
    pub const block = __root.dbus_pending_call_block;
    pub const data = __root.dbus_pending_call_set_data;
};
pub const DBusPendingCall = struct_DBusPendingCall;
pub const struct_DBusConnection = opaque {
    pub const dbus_connection_ref = __root.dbus_connection_ref;
    pub const dbus_connection_unref = __root.dbus_connection_unref;
    pub const dbus_connection_close = __root.dbus_connection_close;
    pub const dbus_connection_get_is_connected = __root.dbus_connection_get_is_connected;
    pub const dbus_connection_get_is_authenticated = __root.dbus_connection_get_is_authenticated;
    pub const dbus_connection_get_is_anonymous = __root.dbus_connection_get_is_anonymous;
    pub const dbus_connection_get_server_id = __root.dbus_connection_get_server_id;
    pub const dbus_connection_can_send_type = __root.dbus_connection_can_send_type;
    pub const dbus_connection_set_exit_on_disconnect = __root.dbus_connection_set_exit_on_disconnect;
    pub const dbus_connection_flush = __root.dbus_connection_flush;
    pub const dbus_connection_read_write_dispatch = __root.dbus_connection_read_write_dispatch;
    pub const dbus_connection_read_write = __root.dbus_connection_read_write;
    pub const dbus_connection_borrow_message = __root.dbus_connection_borrow_message;
    pub const dbus_connection_return_message = __root.dbus_connection_return_message;
    pub const dbus_connection_steal_borrowed_message = __root.dbus_connection_steal_borrowed_message;
    pub const dbus_connection_pop_message = __root.dbus_connection_pop_message;
    pub const dbus_connection_get_dispatch_status = __root.dbus_connection_get_dispatch_status;
    pub const dbus_connection_dispatch = __root.dbus_connection_dispatch;
    pub const dbus_connection_has_messages_to_send = __root.dbus_connection_has_messages_to_send;
    pub const dbus_connection_send = __root.dbus_connection_send;
    pub const dbus_connection_send_with_reply = __root.dbus_connection_send_with_reply;
    pub const dbus_connection_send_with_reply_and_block = __root.dbus_connection_send_with_reply_and_block;
    pub const dbus_connection_set_watch_functions = __root.dbus_connection_set_watch_functions;
    pub const dbus_connection_set_timeout_functions = __root.dbus_connection_set_timeout_functions;
    pub const dbus_connection_set_wakeup_main_function = __root.dbus_connection_set_wakeup_main_function;
    pub const dbus_connection_set_dispatch_status_function = __root.dbus_connection_set_dispatch_status_function;
    pub const dbus_connection_get_unix_user = __root.dbus_connection_get_unix_user;
    pub const dbus_connection_get_unix_process_id = __root.dbus_connection_get_unix_process_id;
    pub const dbus_connection_get_adt_audit_session_data = __root.dbus_connection_get_adt_audit_session_data;
    pub const dbus_connection_set_unix_user_function = __root.dbus_connection_set_unix_user_function;
    pub const dbus_connection_get_windows_user = __root.dbus_connection_get_windows_user;
    pub const dbus_connection_set_windows_user_function = __root.dbus_connection_set_windows_user_function;
    pub const dbus_connection_set_allow_anonymous = __root.dbus_connection_set_allow_anonymous;
    pub const dbus_connection_set_builtin_filters_enabled = __root.dbus_connection_set_builtin_filters_enabled;
    pub const dbus_connection_set_route_peer_messages = __root.dbus_connection_set_route_peer_messages;
    pub const dbus_connection_add_filter = __root.dbus_connection_add_filter;
    pub const dbus_connection_remove_filter = __root.dbus_connection_remove_filter;
    pub const dbus_connection_set_data = __root.dbus_connection_set_data;
    pub const dbus_connection_get_data = __root.dbus_connection_get_data;
    pub const dbus_connection_set_max_message_size = __root.dbus_connection_set_max_message_size;
    pub const dbus_connection_get_max_message_size = __root.dbus_connection_get_max_message_size;
    pub const dbus_connection_set_max_received_size = __root.dbus_connection_set_max_received_size;
    pub const dbus_connection_get_max_received_size = __root.dbus_connection_get_max_received_size;
    pub const dbus_connection_set_max_message_unix_fds = __root.dbus_connection_set_max_message_unix_fds;
    pub const dbus_connection_get_max_message_unix_fds = __root.dbus_connection_get_max_message_unix_fds;
    pub const dbus_connection_set_max_received_unix_fds = __root.dbus_connection_set_max_received_unix_fds;
    pub const dbus_connection_get_max_received_unix_fds = __root.dbus_connection_get_max_received_unix_fds;
    pub const dbus_connection_get_outgoing_size = __root.dbus_connection_get_outgoing_size;
    pub const dbus_connection_get_outgoing_unix_fds = __root.dbus_connection_get_outgoing_unix_fds;
    pub const dbus_connection_preallocate_send = __root.dbus_connection_preallocate_send;
    pub const dbus_connection_free_preallocated_send = __root.dbus_connection_free_preallocated_send;
    pub const dbus_connection_send_preallocated = __root.dbus_connection_send_preallocated;
    pub const dbus_connection_try_register_object_path = __root.dbus_connection_try_register_object_path;
    pub const dbus_connection_register_object_path = __root.dbus_connection_register_object_path;
    pub const dbus_connection_try_register_fallback = __root.dbus_connection_try_register_fallback;
    pub const dbus_connection_register_fallback = __root.dbus_connection_register_fallback;
    pub const dbus_connection_unregister_object_path = __root.dbus_connection_unregister_object_path;
    pub const dbus_connection_get_object_path_data = __root.dbus_connection_get_object_path_data;
    pub const dbus_connection_list_registered = __root.dbus_connection_list_registered;
    pub const dbus_connection_get_unix_fd = __root.dbus_connection_get_unix_fd;
    pub const dbus_connection_get_socket = __root.dbus_connection_get_socket;
    pub const dbus_bus_register = __root.dbus_bus_register;
    pub const dbus_bus_set_unique_name = __root.dbus_bus_set_unique_name;
    pub const dbus_bus_get_unique_name = __root.dbus_bus_get_unique_name;
    pub const dbus_bus_get_unix_user = __root.dbus_bus_get_unix_user;
    pub const dbus_bus_get_id = __root.dbus_bus_get_id;
    pub const dbus_bus_request_name = __root.dbus_bus_request_name;
    pub const dbus_bus_release_name = __root.dbus_bus_release_name;
    pub const dbus_bus_name_has_owner = __root.dbus_bus_name_has_owner;
    pub const dbus_bus_start_service_by_name = __root.dbus_bus_start_service_by_name;
    pub const dbus_bus_add_match = __root.dbus_bus_add_match;
    pub const dbus_bus_remove_match = __root.dbus_bus_remove_match;
    pub const ref = __root.dbus_connection_ref;
    pub const unref = __root.dbus_connection_unref;
    pub const close = __root.dbus_connection_close;
    pub const connected = __root.dbus_connection_get_is_connected;
    pub const authenticated = __root.dbus_connection_get_is_authenticated;
    pub const anonymous = __root.dbus_connection_get_is_anonymous;
    pub const id = __root.dbus_connection_get_server_id;
    pub const @"type" = __root.dbus_connection_can_send_type;
    pub const disconnect = __root.dbus_connection_set_exit_on_disconnect;
    pub const flush = __root.dbus_connection_flush;
    pub const dispatch = __root.dbus_connection_read_write_dispatch;
    pub const write = __root.dbus_connection_read_write;
    pub const message = __root.dbus_connection_borrow_message;
    pub const status = __root.dbus_connection_get_dispatch_status;
    pub const send = __root.dbus_connection_has_messages_to_send;
    pub const reply = __root.dbus_connection_send_with_reply;
    pub const block = __root.dbus_connection_send_with_reply_and_block;
    pub const functions = __root.dbus_connection_set_watch_functions;
    pub const function = __root.dbus_connection_set_wakeup_main_function;
    pub const user = __root.dbus_connection_get_unix_user;
    pub const data = __root.dbus_connection_get_adt_audit_session_data;
    pub const enabled = __root.dbus_connection_set_builtin_filters_enabled;
    pub const messages = __root.dbus_connection_set_route_peer_messages;
    pub const filter = __root.dbus_connection_add_filter;
    pub const size = __root.dbus_connection_set_max_message_size;
    pub const fds = __root.dbus_connection_set_max_message_unix_fds;
    pub const preallocated = __root.dbus_connection_send_preallocated;
    pub const path = __root.dbus_connection_try_register_object_path;
    pub const fallback = __root.dbus_connection_try_register_fallback;
    pub const registered = __root.dbus_connection_list_registered;
    pub const fd = __root.dbus_connection_get_unix_fd;
    pub const socket = __root.dbus_connection_get_socket;
    pub const register = __root.dbus_bus_register;
    pub const name = __root.dbus_bus_set_unique_name;
    pub const owner = __root.dbus_bus_name_has_owner;
    pub const match = __root.dbus_bus_add_match;
};
pub const DBusConnection = struct_DBusConnection;
pub const DBusObjectPathUnregisterFunction = ?*const fn (connection: ?*DBusConnection, user_data: ?*anyopaque) callconv(.c) void;
pub const DBusObjectPathMessageFunction = ?*const fn (connection: ?*DBusConnection, message: ?*DBusMessage, user_data: ?*anyopaque) callconv(.c) DBusHandlerResult;
pub const struct_DBusObjectPathVTable = extern struct {
    unregister_function: DBusObjectPathUnregisterFunction = null,
    message_function: DBusObjectPathMessageFunction = null,
    dbus_internal_pad1: ?*const fn (?*anyopaque) callconv(.c) void = null,
    dbus_internal_pad2: ?*const fn (?*anyopaque) callconv(.c) void = null,
    dbus_internal_pad3: ?*const fn (?*anyopaque) callconv(.c) void = null,
    dbus_internal_pad4: ?*const fn (?*anyopaque) callconv(.c) void = null,
};
pub const DBusObjectPathVTable = struct_DBusObjectPathVTable;
pub const DBUS_WATCH_READABLE: c_int = 1;
pub const DBUS_WATCH_WRITABLE: c_int = 2;
pub const DBUS_WATCH_ERROR: c_int = 4;
pub const DBUS_WATCH_HANGUP: c_int = 8;
pub const DBusWatchFlags = c_uint;
pub const DBUS_DISPATCH_DATA_REMAINS: c_int = 0;
pub const DBUS_DISPATCH_COMPLETE: c_int = 1;
pub const DBUS_DISPATCH_NEED_MEMORY: c_int = 2;
pub const DBusDispatchStatus = c_uint;
pub const DBusAddWatchFunction = ?*const fn (watch: ?*DBusWatch, data: ?*anyopaque) callconv(.c) dbus_bool_t;
pub const DBusWatchToggledFunction = ?*const fn (watch: ?*DBusWatch, data: ?*anyopaque) callconv(.c) void;
pub const DBusRemoveWatchFunction = ?*const fn (watch: ?*DBusWatch, data: ?*anyopaque) callconv(.c) void;
pub const DBusAddTimeoutFunction = ?*const fn (timeout: ?*DBusTimeout, data: ?*anyopaque) callconv(.c) dbus_bool_t;
pub const DBusTimeoutToggledFunction = ?*const fn (timeout: ?*DBusTimeout, data: ?*anyopaque) callconv(.c) void;
pub const DBusRemoveTimeoutFunction = ?*const fn (timeout: ?*DBusTimeout, data: ?*anyopaque) callconv(.c) void;
pub const DBusDispatchStatusFunction = ?*const fn (connection: ?*DBusConnection, new_status: DBusDispatchStatus, data: ?*anyopaque) callconv(.c) void;
pub const DBusWakeupMainFunction = ?*const fn (data: ?*anyopaque) callconv(.c) void;
pub const DBusAllowUnixUserFunction = ?*const fn (connection: ?*DBusConnection, uid: c_ulong, data: ?*anyopaque) callconv(.c) dbus_bool_t;
pub const DBusAllowWindowsUserFunction = ?*const fn (connection: ?*DBusConnection, user_sid: [*c]const u8, data: ?*anyopaque) callconv(.c) dbus_bool_t;
pub const DBusPendingCallNotifyFunction = ?*const fn (pending: ?*DBusPendingCall, user_data: ?*anyopaque) callconv(.c) void;
pub const DBusHandleMessageFunction = ?*const fn (connection: ?*DBusConnection, message: ?*DBusMessage, user_data: ?*anyopaque) callconv(.c) DBusHandlerResult;
pub extern fn dbus_connection_open(address: [*c]const u8, @"error": ?*DBusError) ?*DBusConnection;
pub extern fn dbus_connection_open_private(address: [*c]const u8, @"error": ?*DBusError) ?*DBusConnection;
pub extern fn dbus_connection_ref(connection: ?*DBusConnection) ?*DBusConnection;
pub extern fn dbus_connection_unref(connection: ?*DBusConnection) void;
pub extern fn dbus_connection_close(connection: ?*DBusConnection) void;
pub extern fn dbus_connection_get_is_connected(connection: ?*DBusConnection) dbus_bool_t;
pub extern fn dbus_connection_get_is_authenticated(connection: ?*DBusConnection) dbus_bool_t;
pub extern fn dbus_connection_get_is_anonymous(connection: ?*DBusConnection) dbus_bool_t;
pub extern fn dbus_connection_get_server_id(connection: ?*DBusConnection) [*c]u8;
pub extern fn dbus_connection_can_send_type(connection: ?*DBusConnection, @"type": c_int) dbus_bool_t;
pub extern fn dbus_connection_set_exit_on_disconnect(connection: ?*DBusConnection, exit_on_disconnect: dbus_bool_t) void;
pub extern fn dbus_connection_flush(connection: ?*DBusConnection) void;
pub extern fn dbus_connection_read_write_dispatch(connection: ?*DBusConnection, timeout_milliseconds: c_int) dbus_bool_t;
pub extern fn dbus_connection_read_write(connection: ?*DBusConnection, timeout_milliseconds: c_int) dbus_bool_t;
pub extern fn dbus_connection_borrow_message(connection: ?*DBusConnection) ?*DBusMessage;
pub extern fn dbus_connection_return_message(connection: ?*DBusConnection, message: ?*DBusMessage) void;
pub extern fn dbus_connection_steal_borrowed_message(connection: ?*DBusConnection, message: ?*DBusMessage) void;
pub extern fn dbus_connection_pop_message(connection: ?*DBusConnection) ?*DBusMessage;
pub extern fn dbus_connection_get_dispatch_status(connection: ?*DBusConnection) DBusDispatchStatus;
pub extern fn dbus_connection_dispatch(connection: ?*DBusConnection) DBusDispatchStatus;
pub extern fn dbus_connection_has_messages_to_send(connection: ?*DBusConnection) dbus_bool_t;
pub extern fn dbus_connection_send(connection: ?*DBusConnection, message: ?*DBusMessage, client_serial: [*c]dbus_uint32_t) dbus_bool_t;
pub extern fn dbus_connection_send_with_reply(connection: ?*DBusConnection, message: ?*DBusMessage, pending_return: [*c]?*DBusPendingCall, timeout_milliseconds: c_int) dbus_bool_t;
pub extern fn dbus_connection_send_with_reply_and_block(connection: ?*DBusConnection, message: ?*DBusMessage, timeout_milliseconds: c_int, @"error": ?*DBusError) ?*DBusMessage;
pub extern fn dbus_connection_set_watch_functions(connection: ?*DBusConnection, add_function: DBusAddWatchFunction, remove_function: DBusRemoveWatchFunction, toggled_function: DBusWatchToggledFunction, data: ?*anyopaque, free_data_function: DBusFreeFunction) dbus_bool_t;
pub extern fn dbus_connection_set_timeout_functions(connection: ?*DBusConnection, add_function: DBusAddTimeoutFunction, remove_function: DBusRemoveTimeoutFunction, toggled_function: DBusTimeoutToggledFunction, data: ?*anyopaque, free_data_function: DBusFreeFunction) dbus_bool_t;
pub extern fn dbus_connection_set_wakeup_main_function(connection: ?*DBusConnection, wakeup_main_function: DBusWakeupMainFunction, data: ?*anyopaque, free_data_function: DBusFreeFunction) void;
pub extern fn dbus_connection_set_dispatch_status_function(connection: ?*DBusConnection, function: DBusDispatchStatusFunction, data: ?*anyopaque, free_data_function: DBusFreeFunction) void;
pub extern fn dbus_connection_get_unix_user(connection: ?*DBusConnection, uid: [*c]c_ulong) dbus_bool_t;
pub extern fn dbus_connection_get_unix_process_id(connection: ?*DBusConnection, pid: [*c]c_ulong) dbus_bool_t;
pub extern fn dbus_connection_get_adt_audit_session_data(connection: ?*DBusConnection, data: [*c]?*anyopaque, data_size: [*c]dbus_int32_t) dbus_bool_t;
pub extern fn dbus_connection_set_unix_user_function(connection: ?*DBusConnection, function: DBusAllowUnixUserFunction, data: ?*anyopaque, free_data_function: DBusFreeFunction) void;
pub extern fn dbus_connection_get_windows_user(connection: ?*DBusConnection, windows_sid_p: [*c][*c]u8) dbus_bool_t;
pub extern fn dbus_connection_set_windows_user_function(connection: ?*DBusConnection, function: DBusAllowWindowsUserFunction, data: ?*anyopaque, free_data_function: DBusFreeFunction) void;
pub extern fn dbus_connection_set_allow_anonymous(connection: ?*DBusConnection, value: dbus_bool_t) void;
pub extern fn dbus_connection_set_builtin_filters_enabled(connection: ?*DBusConnection, value: dbus_bool_t) void;
pub extern fn dbus_connection_set_route_peer_messages(connection: ?*DBusConnection, value: dbus_bool_t) void;
pub extern fn dbus_connection_add_filter(connection: ?*DBusConnection, function: DBusHandleMessageFunction, user_data: ?*anyopaque, free_data_function: DBusFreeFunction) dbus_bool_t;
pub extern fn dbus_connection_remove_filter(connection: ?*DBusConnection, function: DBusHandleMessageFunction, user_data: ?*anyopaque) void;
pub extern fn dbus_connection_allocate_data_slot(slot_p: [*c]dbus_int32_t) dbus_bool_t;
pub extern fn dbus_connection_free_data_slot(slot_p: [*c]dbus_int32_t) void;
pub extern fn dbus_connection_set_data(connection: ?*DBusConnection, slot: dbus_int32_t, data: ?*anyopaque, free_data_func: DBusFreeFunction) dbus_bool_t;
pub extern fn dbus_connection_get_data(connection: ?*DBusConnection, slot: dbus_int32_t) ?*anyopaque;
pub extern fn dbus_connection_set_change_sigpipe(will_modify_sigpipe: dbus_bool_t) void;
pub extern fn dbus_connection_set_max_message_size(connection: ?*DBusConnection, size: c_long) void;
pub extern fn dbus_connection_get_max_message_size(connection: ?*DBusConnection) c_long;
pub extern fn dbus_connection_set_max_received_size(connection: ?*DBusConnection, size: c_long) void;
pub extern fn dbus_connection_get_max_received_size(connection: ?*DBusConnection) c_long;
pub extern fn dbus_connection_set_max_message_unix_fds(connection: ?*DBusConnection, n: c_long) void;
pub extern fn dbus_connection_get_max_message_unix_fds(connection: ?*DBusConnection) c_long;
pub extern fn dbus_connection_set_max_received_unix_fds(connection: ?*DBusConnection, n: c_long) void;
pub extern fn dbus_connection_get_max_received_unix_fds(connection: ?*DBusConnection) c_long;
pub extern fn dbus_connection_get_outgoing_size(connection: ?*DBusConnection) c_long;
pub extern fn dbus_connection_get_outgoing_unix_fds(connection: ?*DBusConnection) c_long;
pub extern fn dbus_connection_preallocate_send(connection: ?*DBusConnection) ?*DBusPreallocatedSend;
pub extern fn dbus_connection_free_preallocated_send(connection: ?*DBusConnection, preallocated: ?*DBusPreallocatedSend) void;
pub extern fn dbus_connection_send_preallocated(connection: ?*DBusConnection, preallocated: ?*DBusPreallocatedSend, message: ?*DBusMessage, client_serial: [*c]dbus_uint32_t) void;
pub extern fn dbus_connection_try_register_object_path(connection: ?*DBusConnection, path: [*c]const u8, vtable: [*c]const DBusObjectPathVTable, user_data: ?*anyopaque, @"error": ?*DBusError) dbus_bool_t;
pub extern fn dbus_connection_register_object_path(connection: ?*DBusConnection, path: [*c]const u8, vtable: [*c]const DBusObjectPathVTable, user_data: ?*anyopaque) dbus_bool_t;
pub extern fn dbus_connection_try_register_fallback(connection: ?*DBusConnection, path: [*c]const u8, vtable: [*c]const DBusObjectPathVTable, user_data: ?*anyopaque, @"error": ?*DBusError) dbus_bool_t;
pub extern fn dbus_connection_register_fallback(connection: ?*DBusConnection, path: [*c]const u8, vtable: [*c]const DBusObjectPathVTable, user_data: ?*anyopaque) dbus_bool_t;
pub extern fn dbus_connection_unregister_object_path(connection: ?*DBusConnection, path: [*c]const u8) dbus_bool_t;
pub extern fn dbus_connection_get_object_path_data(connection: ?*DBusConnection, path: [*c]const u8, data_p: [*c]?*anyopaque) dbus_bool_t;
pub extern fn dbus_connection_list_registered(connection: ?*DBusConnection, parent_path: [*c]const u8, child_entries: [*c][*c][*c]u8) dbus_bool_t;
pub extern fn dbus_connection_get_unix_fd(connection: ?*DBusConnection, fd: [*c]c_int) dbus_bool_t;
pub extern fn dbus_connection_get_socket(connection: ?*DBusConnection, fd: [*c]c_int) dbus_bool_t;
pub fn dbus_clear_connection(arg_pointer_to_connection: [*c]?*DBusConnection) callconv(.c) void {
    var pointer_to_connection = arg_pointer_to_connection;
    _ = &pointer_to_connection;
    while (true) {
        var _pp: [*c]?*DBusConnection = pointer_to_connection;
        _ = &_pp;
        var _value: ?*DBusConnection = _pp.*;
        _ = &_value;
        _pp.* = null;
        if (@as(?*anyopaque, @ptrCast(@alignCast(_value))) != @as(?*anyopaque, null)) {
            dbus_connection_unref(_value);
        }
        if (!false) break;
    }
}
pub extern fn dbus_watch_get_fd(watch: ?*DBusWatch) c_int;
pub extern fn dbus_watch_get_unix_fd(watch: ?*DBusWatch) c_int;
pub extern fn dbus_watch_get_socket(watch: ?*DBusWatch) c_int;
pub extern fn dbus_watch_get_flags(watch: ?*DBusWatch) c_uint;
pub extern fn dbus_watch_get_data(watch: ?*DBusWatch) ?*anyopaque;
pub extern fn dbus_watch_set_data(watch: ?*DBusWatch, data: ?*anyopaque, free_data_function: DBusFreeFunction) void;
pub extern fn dbus_watch_handle(watch: ?*DBusWatch, flags: c_uint) dbus_bool_t;
pub extern fn dbus_watch_get_enabled(watch: ?*DBusWatch) dbus_bool_t;
pub extern fn dbus_timeout_get_interval(timeout: ?*DBusTimeout) c_int;
pub extern fn dbus_timeout_get_data(timeout: ?*DBusTimeout) ?*anyopaque;
pub extern fn dbus_timeout_set_data(timeout: ?*DBusTimeout, data: ?*anyopaque, free_data_function: DBusFreeFunction) void;
pub extern fn dbus_timeout_handle(timeout: ?*DBusTimeout) dbus_bool_t;
pub extern fn dbus_timeout_get_enabled(timeout: ?*DBusTimeout) dbus_bool_t;
pub extern fn dbus_bus_get(@"type": DBusBusType, @"error": ?*DBusError) ?*DBusConnection;
pub extern fn dbus_bus_get_private(@"type": DBusBusType, @"error": ?*DBusError) ?*DBusConnection;
pub extern fn dbus_bus_register(connection: ?*DBusConnection, @"error": ?*DBusError) dbus_bool_t;
pub extern fn dbus_bus_set_unique_name(connection: ?*DBusConnection, unique_name: [*c]const u8) dbus_bool_t;
pub extern fn dbus_bus_get_unique_name(connection: ?*DBusConnection) [*c]const u8;
pub extern fn dbus_bus_get_unix_user(connection: ?*DBusConnection, name: [*c]const u8, @"error": ?*DBusError) c_ulong;
pub extern fn dbus_bus_get_id(connection: ?*DBusConnection, @"error": ?*DBusError) [*c]u8;
pub extern fn dbus_bus_request_name(connection: ?*DBusConnection, name: [*c]const u8, flags: c_uint, @"error": ?*DBusError) c_int;
pub extern fn dbus_bus_release_name(connection: ?*DBusConnection, name: [*c]const u8, @"error": ?*DBusError) c_int;
pub extern fn dbus_bus_name_has_owner(connection: ?*DBusConnection, name: [*c]const u8, @"error": ?*DBusError) dbus_bool_t;
pub extern fn dbus_bus_start_service_by_name(connection: ?*DBusConnection, name: [*c]const u8, flags: dbus_uint32_t, reply: [*c]dbus_uint32_t, @"error": ?*DBusError) dbus_bool_t;
pub extern fn dbus_bus_add_match(connection: ?*DBusConnection, rule: [*c]const u8, @"error": ?*DBusError) void;
pub extern fn dbus_bus_remove_match(connection: ?*DBusConnection, rule: [*c]const u8, @"error": ?*DBusError) void;
pub extern fn dbus_get_local_machine_id() [*c]u8;
pub extern fn dbus_get_version(major_version_p: [*c]c_int, minor_version_p: [*c]c_int, micro_version_p: [*c]c_int) void;
pub extern fn dbus_setenv(variable: [*c]const u8, value: [*c]const u8) dbus_bool_t;
pub extern fn dbus_try_get_local_machine_id(@"error": ?*DBusError) [*c]u8;
pub extern fn dbus_pending_call_ref(pending: ?*DBusPendingCall) ?*DBusPendingCall;
pub extern fn dbus_pending_call_unref(pending: ?*DBusPendingCall) void;
pub extern fn dbus_pending_call_set_notify(pending: ?*DBusPendingCall, function: DBusPendingCallNotifyFunction, user_data: ?*anyopaque, free_user_data: DBusFreeFunction) dbus_bool_t;
pub extern fn dbus_pending_call_cancel(pending: ?*DBusPendingCall) void;
pub extern fn dbus_pending_call_get_completed(pending: ?*DBusPendingCall) dbus_bool_t;
pub extern fn dbus_pending_call_steal_reply(pending: ?*DBusPendingCall) ?*DBusMessage;
pub extern fn dbus_pending_call_block(pending: ?*DBusPendingCall) void;
pub extern fn dbus_pending_call_allocate_data_slot(slot_p: [*c]dbus_int32_t) dbus_bool_t;
pub extern fn dbus_pending_call_free_data_slot(slot_p: [*c]dbus_int32_t) void;
pub extern fn dbus_pending_call_set_data(pending: ?*DBusPendingCall, slot: dbus_int32_t, data: ?*anyopaque, free_data_func: DBusFreeFunction) dbus_bool_t;
pub extern fn dbus_pending_call_get_data(pending: ?*DBusPendingCall, slot: dbus_int32_t) ?*anyopaque;
pub fn dbus_clear_pending_call(arg_pointer_to_pending_call: [*c]?*DBusPendingCall) callconv(.c) void {
    var pointer_to_pending_call = arg_pointer_to_pending_call;
    _ = &pointer_to_pending_call;
    while (true) {
        var _pp: [*c]?*DBusPendingCall = pointer_to_pending_call;
        _ = &_pp;
        var _value: ?*DBusPendingCall = _pp.*;
        _ = &_value;
        _pp.* = null;
        if (@as(?*anyopaque, @ptrCast(@alignCast(_value))) != @as(?*anyopaque, null)) {
            dbus_pending_call_unref(_value);
        }
        if (!false) break;
    }
}
pub const struct_DBusServer = opaque {
    pub const dbus_server_ref = __root.dbus_server_ref;
    pub const dbus_server_unref = __root.dbus_server_unref;
    pub const dbus_server_disconnect = __root.dbus_server_disconnect;
    pub const dbus_server_get_is_connected = __root.dbus_server_get_is_connected;
    pub const dbus_server_get_address = __root.dbus_server_get_address;
    pub const dbus_server_get_id = __root.dbus_server_get_id;
    pub const dbus_server_set_new_connection_function = __root.dbus_server_set_new_connection_function;
    pub const dbus_server_set_watch_functions = __root.dbus_server_set_watch_functions;
    pub const dbus_server_set_timeout_functions = __root.dbus_server_set_timeout_functions;
    pub const dbus_server_set_auth_mechanisms = __root.dbus_server_set_auth_mechanisms;
    pub const dbus_server_set_data = __root.dbus_server_set_data;
    pub const dbus_server_get_data = __root.dbus_server_get_data;
    pub const ref = __root.dbus_server_ref;
    pub const unref = __root.dbus_server_unref;
    pub const disconnect = __root.dbus_server_disconnect;
    pub const connected = __root.dbus_server_get_is_connected;
    pub const address = __root.dbus_server_get_address;
    pub const id = __root.dbus_server_get_id;
    pub const function = __root.dbus_server_set_new_connection_function;
    pub const functions = __root.dbus_server_set_watch_functions;
    pub const mechanisms = __root.dbus_server_set_auth_mechanisms;
    pub const data = __root.dbus_server_set_data;
};
pub const DBusServer = struct_DBusServer;
pub const DBusNewConnectionFunction = ?*const fn (server: ?*DBusServer, new_connection: ?*DBusConnection, data: ?*anyopaque) callconv(.c) void;
pub extern fn dbus_server_listen(address: [*c]const u8, @"error": ?*DBusError) ?*DBusServer;
pub extern fn dbus_server_ref(server: ?*DBusServer) ?*DBusServer;
pub extern fn dbus_server_unref(server: ?*DBusServer) void;
pub extern fn dbus_server_disconnect(server: ?*DBusServer) void;
pub extern fn dbus_server_get_is_connected(server: ?*DBusServer) dbus_bool_t;
pub extern fn dbus_server_get_address(server: ?*DBusServer) [*c]u8;
pub extern fn dbus_server_get_id(server: ?*DBusServer) [*c]u8;
pub extern fn dbus_server_set_new_connection_function(server: ?*DBusServer, function: DBusNewConnectionFunction, data: ?*anyopaque, free_data_function: DBusFreeFunction) void;
pub extern fn dbus_server_set_watch_functions(server: ?*DBusServer, add_function: DBusAddWatchFunction, remove_function: DBusRemoveWatchFunction, toggled_function: DBusWatchToggledFunction, data: ?*anyopaque, free_data_function: DBusFreeFunction) dbus_bool_t;
pub extern fn dbus_server_set_timeout_functions(server: ?*DBusServer, add_function: DBusAddTimeoutFunction, remove_function: DBusRemoveTimeoutFunction, toggled_function: DBusTimeoutToggledFunction, data: ?*anyopaque, free_data_function: DBusFreeFunction) dbus_bool_t;
pub extern fn dbus_server_set_auth_mechanisms(server: ?*DBusServer, mechanisms: [*c][*c]const u8) dbus_bool_t;
pub extern fn dbus_server_allocate_data_slot(slot_p: [*c]dbus_int32_t) dbus_bool_t;
pub extern fn dbus_server_free_data_slot(slot_p: [*c]dbus_int32_t) void;
pub extern fn dbus_server_set_data(server: ?*DBusServer, slot: c_int, data: ?*anyopaque, free_data_func: DBusFreeFunction) dbus_bool_t;
pub extern fn dbus_server_get_data(server: ?*DBusServer, slot: c_int) ?*anyopaque;
pub fn dbus_clear_server(arg_pointer_to_server: [*c]?*DBusServer) callconv(.c) void {
    var pointer_to_server = arg_pointer_to_server;
    _ = &pointer_to_server;
    while (true) {
        var _pp: [*c]?*DBusServer = pointer_to_server;
        _ = &_pp;
        var _value: ?*DBusServer = _pp.*;
        _ = &_value;
        _pp.* = null;
        if (@as(?*anyopaque, @ptrCast(@alignCast(_value))) != @as(?*anyopaque, null)) {
            dbus_server_unref(_value);
        }
        if (!false) break;
    }
}
pub const DBusSignatureIter = extern struct {
    dummy1: ?*anyopaque = null,
    dummy2: ?*anyopaque = null,
    dummy8: dbus_uint32_t = 0,
    dummy12: c_int = 0,
    dummy17: c_int = 0,
    pub const dbus_signature_iter_init = __root.dbus_signature_iter_init;
    pub const dbus_signature_iter_get_current_type = __root.dbus_signature_iter_get_current_type;
    pub const dbus_signature_iter_get_signature = __root.dbus_signature_iter_get_signature;
    pub const dbus_signature_iter_get_element_type = __root.dbus_signature_iter_get_element_type;
    pub const dbus_signature_iter_next = __root.dbus_signature_iter_next;
    pub const dbus_signature_iter_recurse = __root.dbus_signature_iter_recurse;
    pub const init = __root.dbus_signature_iter_init;
    pub const @"type" = __root.dbus_signature_iter_get_current_type;
    pub const signature = __root.dbus_signature_iter_get_signature;
    pub const next = __root.dbus_signature_iter_next;
    pub const recurse = __root.dbus_signature_iter_recurse;
};
pub extern fn dbus_signature_iter_init(iter: [*c]DBusSignatureIter, signature: [*c]const u8) void;
pub extern fn dbus_signature_iter_get_current_type(iter: [*c]const DBusSignatureIter) c_int;
pub extern fn dbus_signature_iter_get_signature(iter: [*c]const DBusSignatureIter) [*c]u8;
pub extern fn dbus_signature_iter_get_element_type(iter: [*c]const DBusSignatureIter) c_int;
pub extern fn dbus_signature_iter_next(iter: [*c]DBusSignatureIter) dbus_bool_t;
pub extern fn dbus_signature_iter_recurse(iter: [*c]const DBusSignatureIter, subiter: [*c]DBusSignatureIter) void;
pub extern fn dbus_signature_validate(signature: [*c]const u8, @"error": ?*DBusError) dbus_bool_t;
pub extern fn dbus_signature_validate_single(signature: [*c]const u8, @"error": ?*DBusError) dbus_bool_t;
pub extern fn dbus_type_is_valid(typecode: c_int) dbus_bool_t;
pub extern fn dbus_type_is_basic(typecode: c_int) dbus_bool_t;
pub extern fn dbus_type_is_container(typecode: c_int) dbus_bool_t;
pub extern fn dbus_type_is_fixed(typecode: c_int) dbus_bool_t;
pub extern fn dbus_validate_path(path: [*c]const u8, @"error": ?*DBusError) dbus_bool_t;
pub extern fn dbus_validate_interface(name: [*c]const u8, @"error": ?*DBusError) dbus_bool_t;
pub extern fn dbus_validate_member(name: [*c]const u8, @"error": ?*DBusError) dbus_bool_t;
pub extern fn dbus_validate_error_name(name: [*c]const u8, @"error": ?*DBusError) dbus_bool_t;
pub extern fn dbus_validate_bus_name(name: [*c]const u8, @"error": ?*DBusError) dbus_bool_t;
pub extern fn dbus_validate_utf8(alleged_utf8: [*c]const u8, @"error": ?*DBusError) dbus_bool_t;
pub const struct_DBusMutex = opaque {};
pub const DBusMutex = struct_DBusMutex;
pub const struct_DBusCondVar = opaque {};
pub const DBusCondVar = struct_DBusCondVar;
pub const DBusMutexNewFunction = ?*const fn () callconv(.c) ?*DBusMutex;
pub const DBusMutexFreeFunction = ?*const fn (mutex: ?*DBusMutex) callconv(.c) void;
pub const DBusMutexLockFunction = ?*const fn (mutex: ?*DBusMutex) callconv(.c) dbus_bool_t;
pub const DBusMutexUnlockFunction = ?*const fn (mutex: ?*DBusMutex) callconv(.c) dbus_bool_t;
pub const DBusRecursiveMutexNewFunction = ?*const fn () callconv(.c) ?*DBusMutex;
pub const DBusRecursiveMutexFreeFunction = ?*const fn (mutex: ?*DBusMutex) callconv(.c) void;
pub const DBusRecursiveMutexLockFunction = ?*const fn (mutex: ?*DBusMutex) callconv(.c) void;
pub const DBusRecursiveMutexUnlockFunction = ?*const fn (mutex: ?*DBusMutex) callconv(.c) void;
pub const DBusCondVarNewFunction = ?*const fn () callconv(.c) ?*DBusCondVar;
pub const DBusCondVarFreeFunction = ?*const fn (cond: ?*DBusCondVar) callconv(.c) void;
pub const DBusCondVarWaitFunction = ?*const fn (cond: ?*DBusCondVar, mutex: ?*DBusMutex) callconv(.c) void;
pub const DBusCondVarWaitTimeoutFunction = ?*const fn (cond: ?*DBusCondVar, mutex: ?*DBusMutex, timeout_milliseconds: c_int) callconv(.c) dbus_bool_t;
pub const DBusCondVarWakeOneFunction = ?*const fn (cond: ?*DBusCondVar) callconv(.c) void;
pub const DBusCondVarWakeAllFunction = ?*const fn (cond: ?*DBusCondVar) callconv(.c) void;
pub const DBUS_THREAD_FUNCTIONS_MUTEX_NEW_MASK: c_int = 1;
pub const DBUS_THREAD_FUNCTIONS_MUTEX_FREE_MASK: c_int = 2;
pub const DBUS_THREAD_FUNCTIONS_MUTEX_LOCK_MASK: c_int = 4;
pub const DBUS_THREAD_FUNCTIONS_MUTEX_UNLOCK_MASK: c_int = 8;
pub const DBUS_THREAD_FUNCTIONS_CONDVAR_NEW_MASK: c_int = 16;
pub const DBUS_THREAD_FUNCTIONS_CONDVAR_FREE_MASK: c_int = 32;
pub const DBUS_THREAD_FUNCTIONS_CONDVAR_WAIT_MASK: c_int = 64;
pub const DBUS_THREAD_FUNCTIONS_CONDVAR_WAIT_TIMEOUT_MASK: c_int = 128;
pub const DBUS_THREAD_FUNCTIONS_CONDVAR_WAKE_ONE_MASK: c_int = 256;
pub const DBUS_THREAD_FUNCTIONS_CONDVAR_WAKE_ALL_MASK: c_int = 512;
pub const DBUS_THREAD_FUNCTIONS_RECURSIVE_MUTEX_NEW_MASK: c_int = 1024;
pub const DBUS_THREAD_FUNCTIONS_RECURSIVE_MUTEX_FREE_MASK: c_int = 2048;
pub const DBUS_THREAD_FUNCTIONS_RECURSIVE_MUTEX_LOCK_MASK: c_int = 4096;
pub const DBUS_THREAD_FUNCTIONS_RECURSIVE_MUTEX_UNLOCK_MASK: c_int = 8192;
pub const DBUS_THREAD_FUNCTIONS_ALL_MASK: c_int = 16383;
pub const DBusThreadFunctionsMask = c_uint;
pub const DBusThreadFunctions = extern struct {
    mask: c_uint = 0,
    mutex_new: DBusMutexNewFunction = null,
    mutex_free: DBusMutexFreeFunction = null,
    mutex_lock: DBusMutexLockFunction = null,
    mutex_unlock: DBusMutexUnlockFunction = null,
    condvar_new: DBusCondVarNewFunction = null,
    condvar_free: DBusCondVarFreeFunction = null,
    condvar_wait: DBusCondVarWaitFunction = null,
    condvar_wait_timeout: DBusCondVarWaitTimeoutFunction = null,
    condvar_wake_one: DBusCondVarWakeOneFunction = null,
    condvar_wake_all: DBusCondVarWakeAllFunction = null,
    recursive_mutex_new: DBusRecursiveMutexNewFunction = null,
    recursive_mutex_free: DBusRecursiveMutexFreeFunction = null,
    recursive_mutex_lock: DBusRecursiveMutexLockFunction = null,
    recursive_mutex_unlock: DBusRecursiveMutexUnlockFunction = null,
    padding1: ?*const fn () callconv(.c) void = null,
    padding2: ?*const fn () callconv(.c) void = null,
    padding3: ?*const fn () callconv(.c) void = null,
    padding4: ?*const fn () callconv(.c) void = null,
    pub const dbus_threads_init = __root.dbus_threads_init;
    pub const init = __root.dbus_threads_init;
};
pub extern fn dbus_threads_init(functions: [*c]const DBusThreadFunctions) dbus_bool_t;
pub extern fn dbus_threads_init_default() dbus_bool_t;

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
pub const DBUS_H = "";
pub const DBUS_ARCH_DEPS_H = "";
pub const DBUS_MACROS_H = "";
pub const DBUS_BEGIN_DECLS = "";
pub const DBUS_END_DECLS = "";
pub const TRUE = @as(c_int, 1);
pub const FALSE = @as(c_int, 0);
pub const NULL = __helpers.cast(?*anyopaque, @as(c_int, 0));
pub const DBUS_DEPRECATED = @compileError("unable to translate macro: undefined identifier `__deprecated__`"); // /usr/include/dbus-1.0/dbus/dbus-macros.h:56:11
pub const _DBUS_GNUC_EXTENSION = @compileError("unable to translate C expr: unexpected token '__extension__'"); // /usr/include/dbus-1.0/dbus/dbus-macros.h:64:11
pub const _DBUS_GNUC_PRINTF = @compileError("unable to translate macro: undefined identifier `__format__`"); // /usr/include/dbus-1.0/dbus/dbus-macros.h:71:9
pub const _DBUS_GNUC_NORETURN = @compileError("unable to translate macro: undefined identifier `__noreturn__`"); // /usr/include/dbus-1.0/dbus/dbus-macros.h:73:9
pub const _DBUS_GNUC_UNUSED = @compileError("unable to translate macro: undefined identifier `__unused__`"); // /usr/include/dbus-1.0/dbus/dbus-macros.h:75:9
pub const DBUS_MALLOC = @compileError("unable to translate macro: undefined identifier `__malloc__`"); // /usr/include/dbus-1.0/dbus/dbus-macros.h:84:9
pub const DBUS_ALLOC_SIZE = @compileError("unable to translate macro: undefined identifier `__alloc_size__`"); // /usr/include/dbus-1.0/dbus/dbus-macros.h:90:9
pub const DBUS_ALLOC_SIZE2 = @compileError("unable to translate macro: undefined identifier `__alloc_size__`"); // /usr/include/dbus-1.0/dbus/dbus-macros.h:91:9
pub const _DBUS_WARN_UNUSED_RESULT = @compileError("unable to translate macro: undefined identifier `warn_unused_result`"); // /usr/include/dbus-1.0/dbus/dbus-macros.h:112:9
pub const DBUS_EXPORT = @compileError("unable to translate macro: undefined identifier `__visibility__`"); // /usr/include/dbus-1.0/dbus/dbus-macros.h:210:11
pub const _dbus_clear_pointer_impl = @compileError("unable to translate macro: undefined identifier `_pp`"); // /usr/include/dbus-1.0/dbus/dbus-macros.h:223:9
pub const DBUS_HAVE_INT64 = @as(c_int, 1);
pub const DBUS_INT64_MODIFIER = "l";
pub const DBUS_INT64_CONSTANT = @compileError("unable to translate macro: undefined identifier `L`"); // /usr/lib64/dbus-1.0/include/dbus/dbus-arch-deps.h:41:9
pub const DBUS_UINT64_CONSTANT = @compileError("unable to translate macro: undefined identifier `UL`"); // /usr/lib64/dbus-1.0/include/dbus/dbus-arch-deps.h:42:9
pub const DBUS_SIZEOF_VOID_P = @as(c_int, 8);
pub const DBUS_MAJOR_VERSION = @as(c_int, 1);
pub const DBUS_MINOR_VERSION = @as(c_int, 16);
pub const DBUS_MICRO_VERSION = @as(c_int, 2);
pub const DBUS_VERSION_STRING = "1.16.2";
pub const DBUS_VERSION = ((@as(c_int, 1) << @as(c_int, 16)) | (@as(c_int, 16) << @as(c_int, 8))) | @as(c_int, 2);
pub const DBUS_ADDRESS_H = "";
pub const DBUS_TYPES_H = "";
pub const __STDC_VERSION_STDDEF_H__ = @as(c_long, 202311);
pub const offsetof = @compileError("unable to translate macro: undefined identifier `__builtin_offsetof`"); // /opt/zig/lib/compiler/aro/include/stddef.h:18:9
pub const DBUS_ERROR_H = "";
pub const DBUS_PROTOCOL_H = "";
pub const DBUS_LITTLE_ENDIAN = 'l';
pub const DBUS_BIG_ENDIAN = 'B';
pub const DBUS_MAJOR_PROTOCOL_VERSION = @as(c_int, 1);
pub const DBUS_TYPE_INVALID = __helpers.cast(c_int, '\x00');
pub const DBUS_TYPE_INVALID_AS_STRING = "\x00";
pub const DBUS_TYPE_BYTE = __helpers.cast(c_int, 'y');
pub const DBUS_TYPE_BYTE_AS_STRING = "y";
pub const DBUS_TYPE_BOOLEAN = __helpers.cast(c_int, 'b');
pub const DBUS_TYPE_BOOLEAN_AS_STRING = "b";
pub const DBUS_TYPE_INT16 = __helpers.cast(c_int, 'n');
pub const DBUS_TYPE_INT16_AS_STRING = "n";
pub const DBUS_TYPE_UINT16 = __helpers.cast(c_int, 'q');
pub const DBUS_TYPE_UINT16_AS_STRING = "q";
pub const DBUS_TYPE_INT32 = __helpers.cast(c_int, 'i');
pub const DBUS_TYPE_INT32_AS_STRING = "i";
pub const DBUS_TYPE_UINT32 = __helpers.cast(c_int, 'u');
pub const DBUS_TYPE_UINT32_AS_STRING = "u";
pub const DBUS_TYPE_INT64 = __helpers.cast(c_int, 'x');
pub const DBUS_TYPE_INT64_AS_STRING = "x";
pub const DBUS_TYPE_UINT64 = __helpers.cast(c_int, 't');
pub const DBUS_TYPE_UINT64_AS_STRING = "t";
pub const DBUS_TYPE_DOUBLE = __helpers.cast(c_int, 'd');
pub const DBUS_TYPE_DOUBLE_AS_STRING = "d";
pub const DBUS_TYPE_STRING = __helpers.cast(c_int, 's');
pub const DBUS_TYPE_STRING_AS_STRING = "s";
pub const DBUS_TYPE_OBJECT_PATH = __helpers.cast(c_int, 'o');
pub const DBUS_TYPE_OBJECT_PATH_AS_STRING = "o";
pub const DBUS_TYPE_SIGNATURE = __helpers.cast(c_int, 'g');
pub const DBUS_TYPE_SIGNATURE_AS_STRING = "g";
pub const DBUS_TYPE_UNIX_FD = __helpers.cast(c_int, 'h');
pub const DBUS_TYPE_UNIX_FD_AS_STRING = "h";
pub const DBUS_TYPE_ARRAY = __helpers.cast(c_int, 'a');
pub const DBUS_TYPE_ARRAY_AS_STRING = "a";
pub const DBUS_TYPE_VARIANT = __helpers.cast(c_int, 'v');
pub const DBUS_TYPE_VARIANT_AS_STRING = "v";
pub const DBUS_TYPE_STRUCT = __helpers.cast(c_int, 'r');
pub const DBUS_TYPE_STRUCT_AS_STRING = "r";
pub const DBUS_TYPE_DICT_ENTRY = __helpers.cast(c_int, 'e');
pub const DBUS_TYPE_DICT_ENTRY_AS_STRING = "e";
pub const DBUS_NUMBER_OF_TYPES = @as(c_int, 16);
pub const DBUS_STRUCT_BEGIN_CHAR = __helpers.cast(c_int, '(');
pub const DBUS_STRUCT_BEGIN_CHAR_AS_STRING = "(";
pub const DBUS_STRUCT_END_CHAR = __helpers.cast(c_int, ')');
pub const DBUS_STRUCT_END_CHAR_AS_STRING = ")";
pub const DBUS_DICT_ENTRY_BEGIN_CHAR = __helpers.cast(c_int, '{');
pub const DBUS_DICT_ENTRY_BEGIN_CHAR_AS_STRING = "{";
pub const DBUS_DICT_ENTRY_END_CHAR = __helpers.cast(c_int, '}');
pub const DBUS_DICT_ENTRY_END_CHAR_AS_STRING = "}";
pub const DBUS_MAXIMUM_NAME_LENGTH = @as(c_int, 255);
pub const DBUS_MAXIMUM_SIGNATURE_LENGTH = @as(c_int, 255);
pub const DBUS_MAXIMUM_MATCH_RULE_LENGTH = @as(c_int, 1024);
pub const DBUS_MAXIMUM_MATCH_RULE_ARG_NUMBER = @as(c_int, 63);
pub const DBUS_MAXIMUM_ARRAY_LENGTH = __helpers.promoteIntLiteral(c_int, 67108864, .decimal);
pub const DBUS_MAXIMUM_ARRAY_LENGTH_BITS = @as(c_int, 26);
pub const DBUS_MAXIMUM_MESSAGE_LENGTH = DBUS_MAXIMUM_ARRAY_LENGTH * @as(c_int, 2);
pub const DBUS_MAXIMUM_MESSAGE_LENGTH_BITS = @as(c_int, 27);
pub const DBUS_MAXIMUM_MESSAGE_UNIX_FDS = __helpers.div(DBUS_MAXIMUM_MESSAGE_LENGTH, @as(c_int, 4));
pub const DBUS_MAXIMUM_MESSAGE_UNIX_FDS_BITS = DBUS_MAXIMUM_MESSAGE_LENGTH_BITS - @as(c_int, 2);
pub const DBUS_MAXIMUM_TYPE_RECURSION_DEPTH = @as(c_int, 32);
pub const DBUS_MESSAGE_TYPE_INVALID = @as(c_int, 0);
pub const DBUS_MESSAGE_TYPE_METHOD_CALL = @as(c_int, 1);
pub const DBUS_MESSAGE_TYPE_METHOD_RETURN = @as(c_int, 2);
pub const DBUS_MESSAGE_TYPE_ERROR = @as(c_int, 3);
pub const DBUS_MESSAGE_TYPE_SIGNAL = @as(c_int, 4);
pub const DBUS_NUM_MESSAGE_TYPES = @as(c_int, 5);
pub const DBUS_HEADER_FLAG_NO_REPLY_EXPECTED = @as(c_int, 0x1);
pub const DBUS_HEADER_FLAG_NO_AUTO_START = @as(c_int, 0x2);
pub const DBUS_HEADER_FLAG_ALLOW_INTERACTIVE_AUTHORIZATION = @as(c_int, 0x4);
pub const DBUS_HEADER_FIELD_INVALID = @as(c_int, 0);
pub const DBUS_HEADER_FIELD_PATH = @as(c_int, 1);
pub const DBUS_HEADER_FIELD_INTERFACE = @as(c_int, 2);
pub const DBUS_HEADER_FIELD_MEMBER = @as(c_int, 3);
pub const DBUS_HEADER_FIELD_ERROR_NAME = @as(c_int, 4);
pub const DBUS_HEADER_FIELD_REPLY_SERIAL = @as(c_int, 5);
pub const DBUS_HEADER_FIELD_DESTINATION = @as(c_int, 6);
pub const DBUS_HEADER_FIELD_SENDER = @as(c_int, 7);
pub const DBUS_HEADER_FIELD_SIGNATURE = @as(c_int, 8);
pub const DBUS_HEADER_FIELD_UNIX_FDS = @as(c_int, 9);
pub const DBUS_HEADER_FIELD_CONTAINER_INSTANCE = @as(c_int, 10);
pub const DBUS_HEADER_FIELD_LAST = DBUS_HEADER_FIELD_CONTAINER_INSTANCE;
pub const DBUS_HEADER_SIGNATURE = DBUS_TYPE_BYTE_AS_STRING ++ DBUS_TYPE_BYTE_AS_STRING ++ DBUS_TYPE_BYTE_AS_STRING ++ DBUS_TYPE_BYTE_AS_STRING ++ DBUS_TYPE_UINT32_AS_STRING ++ DBUS_TYPE_UINT32_AS_STRING ++ DBUS_TYPE_ARRAY_AS_STRING ++ DBUS_STRUCT_BEGIN_CHAR_AS_STRING ++ DBUS_TYPE_BYTE_AS_STRING ++ DBUS_TYPE_VARIANT_AS_STRING ++ DBUS_STRUCT_END_CHAR_AS_STRING;
pub const DBUS_MINIMUM_HEADER_SIZE = @as(c_int, 16);
pub const DBUS_ERROR_FAILED = "org.freedesktop.DBus.Error.Failed";
pub const DBUS_ERROR_NO_MEMORY = "org.freedesktop.DBus.Error.NoMemory";
pub const DBUS_ERROR_SERVICE_UNKNOWN = "org.freedesktop.DBus.Error.ServiceUnknown";
pub const DBUS_ERROR_NAME_HAS_NO_OWNER = "org.freedesktop.DBus.Error.NameHasNoOwner";
pub const DBUS_ERROR_NO_REPLY = "org.freedesktop.DBus.Error.NoReply";
pub const DBUS_ERROR_IO_ERROR = "org.freedesktop.DBus.Error.IOError";
pub const DBUS_ERROR_BAD_ADDRESS = "org.freedesktop.DBus.Error.BadAddress";
pub const DBUS_ERROR_NOT_SUPPORTED = "org.freedesktop.DBus.Error.NotSupported";
pub const DBUS_ERROR_LIMITS_EXCEEDED = "org.freedesktop.DBus.Error.LimitsExceeded";
pub const DBUS_ERROR_ACCESS_DENIED = "org.freedesktop.DBus.Error.AccessDenied";
pub const DBUS_ERROR_AUTH_FAILED = "org.freedesktop.DBus.Error.AuthFailed";
pub const DBUS_ERROR_NO_SERVER = "org.freedesktop.DBus.Error.NoServer";
pub const DBUS_ERROR_TIMEOUT = "org.freedesktop.DBus.Error.Timeout";
pub const DBUS_ERROR_NO_NETWORK = "org.freedesktop.DBus.Error.NoNetwork";
pub const DBUS_ERROR_ADDRESS_IN_USE = "org.freedesktop.DBus.Error.AddressInUse";
pub const DBUS_ERROR_DISCONNECTED = "org.freedesktop.DBus.Error.Disconnected";
pub const DBUS_ERROR_INVALID_ARGS = "org.freedesktop.DBus.Error.InvalidArgs";
pub const DBUS_ERROR_FILE_NOT_FOUND = "org.freedesktop.DBus.Error.FileNotFound";
pub const DBUS_ERROR_FILE_EXISTS = "org.freedesktop.DBus.Error.FileExists";
pub const DBUS_ERROR_UNKNOWN_METHOD = "org.freedesktop.DBus.Error.UnknownMethod";
pub const DBUS_ERROR_UNKNOWN_OBJECT = "org.freedesktop.DBus.Error.UnknownObject";
pub const DBUS_ERROR_UNKNOWN_INTERFACE = "org.freedesktop.DBus.Error.UnknownInterface";
pub const DBUS_ERROR_UNKNOWN_PROPERTY = "org.freedesktop.DBus.Error.UnknownProperty";
pub const DBUS_ERROR_PROPERTY_READ_ONLY = "org.freedesktop.DBus.Error.PropertyReadOnly";
pub const DBUS_ERROR_TIMED_OUT = "org.freedesktop.DBus.Error.TimedOut";
pub const DBUS_ERROR_MATCH_RULE_NOT_FOUND = "org.freedesktop.DBus.Error.MatchRuleNotFound";
pub const DBUS_ERROR_MATCH_RULE_INVALID = "org.freedesktop.DBus.Error.MatchRuleInvalid";
pub const DBUS_ERROR_SPAWN_EXEC_FAILED = "org.freedesktop.DBus.Error.Spawn.ExecFailed";
pub const DBUS_ERROR_SPAWN_FORK_FAILED = "org.freedesktop.DBus.Error.Spawn.ForkFailed";
pub const DBUS_ERROR_SPAWN_CHILD_EXITED = "org.freedesktop.DBus.Error.Spawn.ChildExited";
pub const DBUS_ERROR_SPAWN_CHILD_SIGNALED = "org.freedesktop.DBus.Error.Spawn.ChildSignaled";
pub const DBUS_ERROR_SPAWN_FAILED = "org.freedesktop.DBus.Error.Spawn.Failed";
pub const DBUS_ERROR_SPAWN_SETUP_FAILED = "org.freedesktop.DBus.Error.Spawn.FailedToSetup";
pub const DBUS_ERROR_SPAWN_CONFIG_INVALID = "org.freedesktop.DBus.Error.Spawn.ConfigInvalid";
pub const DBUS_ERROR_SPAWN_SERVICE_INVALID = "org.freedesktop.DBus.Error.Spawn.ServiceNotValid";
pub const DBUS_ERROR_SPAWN_SERVICE_NOT_FOUND = "org.freedesktop.DBus.Error.Spawn.ServiceNotFound";
pub const DBUS_ERROR_SPAWN_PERMISSIONS_INVALID = "org.freedesktop.DBus.Error.Spawn.PermissionsInvalid";
pub const DBUS_ERROR_SPAWN_FILE_INVALID = "org.freedesktop.DBus.Error.Spawn.FileInvalid";
pub const DBUS_ERROR_SPAWN_NO_MEMORY = "org.freedesktop.DBus.Error.Spawn.NoMemory";
pub const DBUS_ERROR_UNIX_PROCESS_ID_UNKNOWN = "org.freedesktop.DBus.Error.UnixProcessIdUnknown";
pub const DBUS_ERROR_INVALID_SIGNATURE = "org.freedesktop.DBus.Error.InvalidSignature";
pub const DBUS_ERROR_INVALID_FILE_CONTENT = "org.freedesktop.DBus.Error.InvalidFileContent";
pub const DBUS_ERROR_SELINUX_SECURITY_CONTEXT_UNKNOWN = "org.freedesktop.DBus.Error.SELinuxSecurityContextUnknown";
pub const DBUS_ERROR_ADT_AUDIT_DATA_UNKNOWN = "org.freedesktop.DBus.Error.AdtAuditDataUnknown";
pub const DBUS_ERROR_OBJECT_PATH_IN_USE = "org.freedesktop.DBus.Error.ObjectPathInUse";
pub const DBUS_ERROR_INCONSISTENT_MESSAGE = "org.freedesktop.DBus.Error.InconsistentMessage";
pub const DBUS_ERROR_INTERACTIVE_AUTHORIZATION_REQUIRED = "org.freedesktop.DBus.Error.InteractiveAuthorizationRequired";
pub const DBUS_ERROR_NOT_CONTAINER = "org.freedesktop.DBus.Error.NotContainer";
pub const DBUS_INTROSPECT_1_0_XML_NAMESPACE = "http://www.freedesktop.org/standards/dbus";
pub const DBUS_INTROSPECT_1_0_XML_PUBLIC_IDENTIFIER = "-//freedesktop//DTD D-BUS Object Introspection 1.0//EN";
pub const DBUS_INTROSPECT_1_0_XML_SYSTEM_IDENTIFIER = "http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd";
pub const DBUS_INTROSPECT_1_0_XML_DOCTYPE_DECL_NODE = "<!DOCTYPE node PUBLIC \"" ++ DBUS_INTROSPECT_1_0_XML_PUBLIC_IDENTIFIER ++ "\"\n\"" ++ DBUS_INTROSPECT_1_0_XML_SYSTEM_IDENTIFIER ++ "\">\n";
pub const DBUS_ERROR_INIT = @compileError("unable to translate C expr: unexpected token '{'"); // /usr/include/dbus-1.0/dbus/dbus-errors.h:64:9
pub const DBUS_BUS_H = "";
pub const DBUS_CONNECTION_H = "";
pub const DBUS_MEMORY_H = "";
pub inline fn dbus_new(@"type": anytype, count: anytype) @TypeOf([*c]@"type" ++ dbus_malloc(__helpers.sizeof(@"type") * count)) {
    _ = &@"type";
    _ = &count;
    return [*c]@"type" ++ dbus_malloc(__helpers.sizeof(@"type") * count);
}
pub inline fn dbus_new0(@"type": anytype, count: anytype) @TypeOf([*c]@"type" ++ dbus_malloc0(__helpers.sizeof(@"type") * count)) {
    _ = &@"type";
    _ = &count;
    return [*c]@"type" ++ dbus_malloc0(__helpers.sizeof(@"type") * count);
}
pub const DBUS_MESSAGE_H = "";
pub const __STDC_VERSION_STDARG_H__ = @as(c_int, 0);
pub const va_start = @compileError("unable to translate macro: undefined identifier `__builtin_va_start`"); // /opt/zig/lib/compiler/aro/include/stdarg.h:12:9
pub const va_end = @compileError("unable to translate macro: undefined identifier `__builtin_va_end`"); // /opt/zig/lib/compiler/aro/include/stdarg.h:14:9
pub const va_arg = @compileError("unable to translate macro: undefined identifier `__builtin_va_arg`"); // /opt/zig/lib/compiler/aro/include/stdarg.h:15:9
pub const __va_copy = @compileError("unable to translate macro: undefined identifier `__builtin_va_copy`"); // /opt/zig/lib/compiler/aro/include/stdarg.h:18:9
pub const va_copy = @compileError("unable to translate macro: undefined identifier `__builtin_va_copy`"); // /opt/zig/lib/compiler/aro/include/stdarg.h:22:9
pub const __GNUC_VA_LIST = @as(c_int, 1);
pub const DBUS_MESSAGE_ITER_INIT_CLOSED = @compileError("unable to translate C expr: unexpected token '{'"); // /usr/include/dbus-1.0/dbus/dbus-message.h:100:9
pub const DBUS_SHARED_H = "";
pub const DBUS_SERVICE_DBUS = "org.freedesktop.DBus";
pub const DBUS_PATH_DBUS = "/org/freedesktop/DBus";
pub const DBUS_PATH_LOCAL = "/org/freedesktop/DBus/Local";
pub const DBUS_INTERFACE_DBUS = "org.freedesktop.DBus";
pub const DBUS_INTERFACE_MONITORING = "org.freedesktop.DBus.Monitoring";
pub const DBUS_INTERFACE_VERBOSE = "org.freedesktop.DBus.Verbose";
pub const DBUS_INTERFACE_INTROSPECTABLE = "org.freedesktop.DBus.Introspectable";
pub const DBUS_INTERFACE_PROPERTIES = "org.freedesktop.DBus.Properties";
pub const DBUS_INTERFACE_PEER = "org.freedesktop.DBus.Peer";
pub const DBUS_INTERFACE_LOCAL = "org.freedesktop.DBus.Local";
pub const DBUS_NAME_FLAG_ALLOW_REPLACEMENT = @as(c_int, 0x1);
pub const DBUS_NAME_FLAG_REPLACE_EXISTING = @as(c_int, 0x2);
pub const DBUS_NAME_FLAG_DO_NOT_QUEUE = @as(c_int, 0x4);
pub const DBUS_REQUEST_NAME_REPLY_PRIMARY_OWNER = @as(c_int, 1);
pub const DBUS_REQUEST_NAME_REPLY_IN_QUEUE = @as(c_int, 2);
pub const DBUS_REQUEST_NAME_REPLY_EXISTS = @as(c_int, 3);
pub const DBUS_REQUEST_NAME_REPLY_ALREADY_OWNER = @as(c_int, 4);
pub const DBUS_RELEASE_NAME_REPLY_RELEASED = @as(c_int, 1);
pub const DBUS_RELEASE_NAME_REPLY_NON_EXISTENT = @as(c_int, 2);
pub const DBUS_RELEASE_NAME_REPLY_NOT_OWNER = @as(c_int, 3);
pub const DBUS_START_REPLY_SUCCESS = @as(c_int, 1);
pub const DBUS_START_REPLY_ALREADY_RUNNING = @as(c_int, 2);
pub const DBUS_MISC_H = "";
pub const DBUS_PENDING_CALL_H = "";
pub const DBUS_TIMEOUT_INFINITE = __helpers.cast(c_int, __helpers.promoteIntLiteral(c_int, 0x7fffffff, .hex));
pub const DBUS_TIMEOUT_USE_DEFAULT = -@as(c_int, 1);
pub const DBUS_SERVER_H = "";
pub const DBUS_SIGNATURES_H = "";
pub const DBUS_SYNTAX_H = "";
pub const DBUS_THREADS_H = "";
