// TODO add function pointer ?

const std = @import("std");

const Type = @import("../types.zig").Type;

return_type: *Type,
params: []const Type,

const Self = @This();

pub fn size_of(_: Self) usize {
    return @sizeOf(*anyopaque);
}
