const std = @import("std");

path: ?[]const u8,
data: []const u8,

const Self = @This();

pub fn init(data: []const u8, path: []const u8) Self {
    return Self{ .data = data, .path = path };
}

pub fn init_unnamed(data: []const u8) Self {
    return Self{ .data = data, .path = null };
}

pub fn get_lines(self: Self, start_line: usize) std.mem.SplitIterator(u8, .scalar) {
    var it = std.mem.splitScalar(u8, self.data, '\n');
    var i = start_line;
    while (i > 1) : (i -= 1) {
        _ = it.next();
    }
    return it;
}
