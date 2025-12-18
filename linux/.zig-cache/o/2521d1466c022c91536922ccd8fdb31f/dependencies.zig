pub const packages = struct {
    pub const @"1220ef11f229566a21729a5780ebe0fc8e983891663c8b0a7d793e1a4f53f622f876" = struct {
        pub const available = false;
    };
};

pub const root_deps: []const struct { []const u8, []const u8 } = &.{
    .{ "gobject", "1220ef11f229566a21729a5780ebe0fc8e983891663c8b0a7d793e1a4f53f622f876" },
};
