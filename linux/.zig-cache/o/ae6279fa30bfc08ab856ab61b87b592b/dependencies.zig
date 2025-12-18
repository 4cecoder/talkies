pub const packages = struct {
    pub const @"1220f3596b522be8a7116a7cfca5ce071ad8eefa8120045b0e61b8193ff56404db97" = struct {
        pub const available = false;
    };
};

pub const root_deps: []const struct { []const u8, []const u8 } = &.{
    .{ "gobject", "1220f3596b522be8a7116a7cfca5ce071ad8eefa8120045b0e61b8193ff56404db97" },
};
