const std = @import("std");
pub const VERSION = std.SemanticVersion {
    .major = 0,
    .minor = 1,
    .patch = 0,
    .pre = "alpha",
};

pub const parser = @import("./parser.zig");
pub const ir = @import("./ir.zig");

test {
    _ = parser;
}
