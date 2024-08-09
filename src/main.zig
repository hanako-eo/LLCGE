const std = @import("std");
const testing = std.testing;

pub fn main() void {
    std.debug.print("Hello World!\n", .{});
}

test "import other tests" {
    _ = @import("./parser/parser.zig");
}
