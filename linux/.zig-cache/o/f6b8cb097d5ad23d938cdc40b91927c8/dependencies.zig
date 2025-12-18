pub const packages = struct {
    pub const @"1220a89ee19586333bfef064a66731cd63462f1c750fede9b22d583210a2feeb62ec" = struct {
        pub const build_root = "/home/fource/.cache/zig/p/gobject_codegen-0.3.0-B33qzQhGBwConuGVhjM7_vBkpmcxzWNGLxx1D-3psi1Y";
        pub const build_zig = @import("1220a89ee19586333bfef064a66731cd63462f1c750fede9b22d583210a2feeb62ec");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
            .{ "xml", "xml-0.1.0-ZTbP35UoAgDk1IhivGX2bzjEqMCBy2Q5QQBdrUoNURiJ" },
        };
    };
    pub const @"xml-0.1.0-ZTbP35UoAgDk1IhivGX2bzjEqMCBy2Q5QQBdrUoNURiJ" = struct {
        pub const build_root = "/home/fource/.cache/zig/p/xml-0.1.0-ZTbP35UoAgDk1IhivGX2bzjEqMCBy2Q5QQBdrUoNURiJ";
        pub const build_zig = @import("xml-0.1.0-ZTbP35UoAgDk1IhivGX2bzjEqMCBy2Q5QQBdrUoNURiJ");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
};

pub const root_deps: []const struct { []const u8, []const u8 } = &.{
    .{ "gobject_codegen", "1220a89ee19586333bfef064a66731cd63462f1c750fede9b22d583210a2feeb62ec" },
};
