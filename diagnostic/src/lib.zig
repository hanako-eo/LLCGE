pub const Diagnostic = @import("./diagnostic.zig");
pub const Label = @import("./label.zig");
pub const Location = @import("./location.zig");
pub const Source = @import("./source.zig");
pub const Span = @import("./span.zig");

pub const Severity = enum {
    info,
    warning,
    @"error",
};

const std = @import("std");
const expect = std.testing.expect;
const expectFmt = std.testing.expectFmt;
test "if diagnostic print correctly" {
    const source =
        \\This is a test
        \\of llcge.
    ;
    const d = Diagnostic.init_empty(.warning, Source.init_unnamed(source), Location.init(2, 4, 2, 9), "don't you mean \"diagnostic\" instead?", std.testing.allocator);

    try expectFmt("", "{}", .{d});
}
