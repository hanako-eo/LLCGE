const std = @import("std");
const yazap = @import("yazap");
const zon_parser = @import("./zon_parser.zig");

pub const description = "Release";

pub fn init(_: *yazap.Command) void {}

pub fn main(alloc: std.mem.Allocator) void {
    std.debug.print("{}\n", .{zon_parser.zon_value(".{ .a = \"hello\" ,.b = 0, }", alloc).ok});
}
