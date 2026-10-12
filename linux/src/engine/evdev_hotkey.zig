//! Global Right Alt detection straight from /dev/input, for Wayland where
//! clients cannot grab keys. Requires read access to the keyboard event
//! devices (membership in the `input` group). Only KEY_RIGHTALT is examined;
//! every other event is discarded without being stored or logged.

const std = @import("std");
const linux = std.os.linux;
const utils = @import("core").utils;
const c = @import("c_input");

pub const Event = enum { press, release };

const max_devices = 16;
/// Our own uinput paste keyboard must never be read back.
const own_device_name = "Talkies Virtual Keyboard";

pub const Listener = struct {
    fds: [max_devices]std.posix.fd_t = undefined,
    count: usize = 0,

    /// Open every keyboard that has a Right Alt key. Returns an empty
    /// listener (count == 0) when no device is readable.
    pub fn open() Listener {
        var self: Listener = .{};
        var index: usize = 0;
        while (index < 64 and self.count < max_devices) : (index += 1) {
            var path_buf: [32]u8 = undefined;
            const path = std.fmt.bufPrintSentinel(&path_buf, "/dev/input/event{d}", .{index}, 0) catch continue;
            const rc = linux.open(path.ptr, .{ .ACCMODE = .RDONLY, .NONBLOCK = true, .CLOEXEC = true }, 0);
            if (linux.errno(rc) != .SUCCESS) continue;
            const fd: std.posix.fd_t = @intCast(rc);
            if (isCandidate(fd)) {
                self.fds[self.count] = fd;
                self.count += 1;
            } else {
                _ = linux.close(fd);
            }
        }
        if (self.count > 0) utils.log("Right Alt hotkey: watching {d} keyboard device(s)", .{self.count});
        return self;
    }

    pub fn deinit(self: *Listener) void {
        for (self.fds[0..self.count]) |fd| _ = linux.close(fd);
        self.count = 0;
    }

    pub fn devices(self: *const Listener) []const std.posix.fd_t {
        return self.fds[0..self.count];
    }

    /// Drain one device; returns the last Right Alt transition seen, if any.
    /// Auto-repeat (value 2) is ignored.
    pub fn read(fd: std.posix.fd_t) ?Event {
        var result: ?Event = null;
        var events: [32]c.struct_input_event = undefined;
        while (true) {
            const bytes = std.mem.sliceAsBytes(&events);
            const rc = linux.read(fd, bytes.ptr, bytes.len);
            if (linux.errno(rc) != .SUCCESS or rc == 0) break;
            const n = rc / @sizeOf(c.struct_input_event);
            for (events[0..n]) |ev| {
                if (ev.type != c.EV_KEY or ev.code != c.KEY_RIGHTALT) continue;
                switch (ev.value) {
                    1 => result = .press,
                    0 => result = .release,
                    else => {},
                }
            }
            if (n < events.len) break;
        }
        return result;
    }
};

fn ioc(dir: u32, nr: u32, size: u32) u32 {
    return (dir << 30) | (size << 16) | (@as(u32, 'E') << 8) | nr;
}

const ioc_read: u32 = 2;

fn isCandidate(fd: std.posix.fd_t) bool {
    var name: [256]u8 = std.mem.zeroes([256]u8);
    if (linux.errno(linux.ioctl(fd, ioc(ioc_read, 0x06, name.len), @intFromPtr(&name))) == .SUCCESS) {
        if (std.mem.eql(u8, std.mem.sliceTo(&name, 0), own_device_name)) return false;
    }
    // EVIOCGBIT(EV_KEY): which key codes this device can emit.
    var keys: [(c.KEY_MAX + 8) / 8]u8 = std.mem.zeroes([(c.KEY_MAX + 8) / 8]u8);
    if (linux.errno(linux.ioctl(fd, ioc(ioc_read, 0x20 + c.EV_KEY, keys.len), @intFromPtr(&keys))) != .SUCCESS) return false;
    const code: usize = c.KEY_RIGHTALT;
    return keys[code / 8] & (@as(u8, 1) << @intCast(code % 8)) != 0;
}

test "EVIOCGBIT/EVIOCGNAME encodings match the kernel headers" {
    // EVIOCGNAME(256) = 0x81004506, EVIOCGBIT(EV_KEY, 96) = 0x80604521
    try std.testing.expectEqual(@as(u32, 0x81004506), ioc(ioc_read, 0x06, 256));
    try std.testing.expectEqual(@as(u32, 0x80604521), ioc(ioc_read, 0x20 + 1, 96));
}
