const std = @import("std");

const Type = @import("../types.zig").Type;

return_type: Type,
params: []const Type,

const Self = @This();

pub fn sizeOf(_: Self) usize {
    return @sizeOf(*anyopaque);
}
