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

test "if diagnostic on single line warning print correctly" {
    const source =
        \\This is a test
        \\of llcge.
    ;
    const d = Diagnostic.init_empty(.warning, Source.init_unnamed(source), Location.init(2, 4, 2, 9), "don't you mean \"diagnostic\" instead?", std.testing.allocator);

    try expectFmt("\x1B[33mwarning\x1B[0m in ~memory:2:4:\n -> don't you mean \"diagnostic\" instead?\n 2 | of llcge.\n   |    \x1B[33m^^^^^\x1B[0m", "{}", .{d});
}

test "if diagnostic on multi line error print correctly" {
    const source =
        \\This is a test
        \\of llcge.
    ;
    const d = Diagnostic.init_empty(.@"error", Source.init_unnamed(source), Location.init(1, 1, 2, 10), "this sentence is not correct", std.testing.allocator);

    try expectFmt("\x1B[31merror\x1B[0m in ~memory:1:1:\n -> this sentence is not correct\n 1 | \x1B[31m/\x1B[0m This is a test\n 2 | \x1B[31m|\x1B[0m of llcge.\n     \x1B[31m\\---------/\x1B[0m", "{}", .{d});
}

test "if diagnostic on multi line error print correctly without color" {
    const Color = @import("utils").Color;
    Color.force_usage(false);

    const source =
        \\This is a test
        \\of llcge.
    ;
    const d = Diagnostic.init_empty(.@"error", Source.init_unnamed(source), Location.init(1, 1, 2, 10), "this sentence is not correct", std.testing.allocator);

    try expectFmt("error in ~memory:1:1:\n -> this sentence is not correct\n 1 | / This is a test\n 2 | | of llcge.\n     \\---------/", "{}", .{d});
}
